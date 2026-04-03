import base64
import hashlib
import hmac
import io
import json
import logging
import re
import secrets
import string
import time
import uuid
from collections import defaultdict

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from PIL import Image, ImageDraw, ImageFont
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..models import AuthAuditLog, User
from ..schemas import CaptchaResponse, TokenResponse, UserLogin, UserRegister, UserResponse

router = APIRouter()

SECRET_KEY = settings.SECRET_KEY
_captcha_store: dict[str, dict[str, float | str]] = {}
_rate_limit_store: dict[str, list[float]] = defaultdict(list)
_login_fail_store: dict[str, dict[str, float | int]] = {}

logger = logging.getLogger("auth")

RATE_LIMIT_WINDOW = settings.AUTH_RATE_LIMIT_WINDOW
CAPTCHA_MAX_PER_WINDOW = settings.AUTH_CAPTCHA_MAX_PER_WINDOW
REGISTER_MAX_PER_WINDOW = settings.AUTH_REGISTER_MAX_PER_WINDOW
LOGIN_MAX_PER_WINDOW = settings.AUTH_LOGIN_MAX_PER_WINDOW
LOGIN_FAIL_MAX = settings.AUTH_LOGIN_FAIL_MAX
LOGIN_LOCK_SECONDS = settings.AUTH_LOGIN_LOCK_SECONDS


def hash_password(password: str) -> str:
    iterations = 120000
    salt = secrets.token_hex(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), iterations)
    return f"pbkdf2_sha256${iterations}${salt}${base64.urlsafe_b64encode(dk).decode()}"


def verify_password(stored_hash: str, password: str) -> bool:
    if stored_hash.startswith("pbkdf2_sha256$"):
        try:
            _, iter_str, salt, expected = stored_hash.split("$", 3)
            iterations = int(iter_str)
            dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), iterations)
            actual = base64.urlsafe_b64encode(dk).decode()
            return hmac.compare_digest(actual, expected)
        except Exception:
            return False

    legacy_hash = hashlib.sha256(password.encode()).hexdigest()
    return hmac.compare_digest(legacy_hash, stored_hash)


def _b64_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def _b64_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def create_token(user_id: int, username: str, role: str) -> str:
    now = int(time.time())
    payload = {
        "user_id": user_id,
        "username": username,
        "role": role,
        "iat": now,
        "exp": now + settings.TOKEN_EXPIRE_HOURS * 3600,
    }
    payload_bytes = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    payload_str = _b64_encode(payload_bytes)
    sig = hmac.new(SECRET_KEY.encode(), payload_str.encode(), hashlib.sha256).digest()
    return f"{payload_str}.{_b64_encode(sig)}"


def verify_token(token: str) -> dict | None:
    try:
        parts = token.split(".")
        if len(parts) != 2:
            return None
        payload_str, sig_str = parts
        expected_sig = hmac.new(SECRET_KEY.encode(), payload_str.encode(), hashlib.sha256).digest()
        actual_sig = _b64_decode(sig_str)
        if not hmac.compare_digest(actual_sig, expected_sig):
            return None
        payload = json.loads(_b64_decode(payload_str))
        if payload.get("exp", 0) < time.time():
            return None
        return payload
    except Exception:
        return None


def validate_password(password: str) -> str | None:
    if len(password) < 8:
        return "Password length must be at least 8."
    if not re.search(r"[A-Z]", password):
        return "Password must contain an uppercase letter."
    if not re.search(r"[a-z]", password):
        return "Password must contain a lowercase letter."
    if not re.search(r"[0-9]", password):
        return "Password must contain a digit."
    if not re.search(r"[!@#$%^&*()_+\-=\[\]{};':\"\\|,.<>/?~`]", password):
        return "Password must contain a special character."
    return None


def cleanup_expired_captchas() -> None:
    now = time.time()
    expired_keys = [k for k, v in _captcha_store.items() if float(v["expire"]) < now]
    for key in expired_keys:
        del _captcha_store[key]


def _cleanup_rate_limit(now: float, key: str, window: int) -> None:
    _rate_limit_store[key] = [ts for ts in _rate_limit_store.get(key, []) if now - ts < window]


def _is_rate_limited(key: str, max_requests: int, window: int) -> bool:
    now = time.time()
    _cleanup_rate_limit(now, key, window)
    records = _rate_limit_store.get(key, [])
    if len(records) >= max_requests:
        return True
    records.append(now)
    _rate_limit_store[key] = records
    return False


def _record_login_failure(username: str) -> tuple[int, int]:
    now = time.time()
    state = _login_fail_store.get(username, {"count": 0, "locked_until": 0.0})
    if float(state.get("locked_until", 0.0)) <= now:
        state["count"] = int(state.get("count", 0)) + 1
    if int(state["count"]) >= LOGIN_FAIL_MAX:
        state["locked_until"] = now + LOGIN_LOCK_SECONDS
    _login_fail_store[username] = state
    remaining = max(0, int(float(state.get("locked_until", 0.0)) - now))
    return int(state["count"]), remaining


def _clear_login_failure(username: str) -> None:
    if username in _login_fail_store:
        del _login_fail_store[username]


def _is_login_locked(username: str) -> tuple[bool, int]:
    state = _login_fail_store.get(username)
    if not state:
        return False, 0
    now = time.time()
    locked_until = float(state.get("locked_until", 0.0))
    if locked_until > now:
        return True, int(locked_until - now)
    return False, 0


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "").strip()
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _audit(
    db: Session,
    event_type: str,
    username: str,
    ip: str,
    status: str,
    reason: str = "",
) -> None:
    try:
        db.add(
            AuthAuditLog(
                event_type=event_type,
                username=username or "",
                ip=ip or "",
                status=status,
                reason=reason or "",
            )
        )
        db.commit()
    except Exception:
        db.rollback()


def build_captcha_image(code: str) -> str:
    img = Image.new("RGB", (120, 48), color=(92, 107, 192))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 28)
    except Exception:
        font = ImageFont.load_default()

    for _ in range(6):
        x1 = secrets.randbelow(120)
        y1 = secrets.randbelow(48)
        x2 = secrets.randbelow(120)
        y2 = secrets.randbelow(48)
        draw.line((x1, y1, x2, y2), fill=(255, 255, 255), width=1)

    for i, ch in enumerate(code):
        x = 12 + i * 24 + secrets.randbelow(3)
        y = 8 + secrets.randbelow(6)
        draw.text((x, y), ch, font=font, fill=(255, 255, 255))

    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode()


def get_current_user(authorization: str = Header(None), db: Session = Depends(get_db)) -> User:
    if not authorization:
        raise HTTPException(status_code=401, detail="Not authenticated.")
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header.")
    token = authorization.replace("Bearer ", "", 1)
    user = get_user_from_token(token, db)
    if not user:
        raise HTTPException(status_code=401, detail="Token expired or invalid.")
    return user


def get_user_from_token(token: str, db: Session) -> User | None:
    payload = verify_token(token)
    if not payload:
        return None
    user_id = payload.get("user_id")
    if not isinstance(user_id, int):
        return None
    return db.query(User).filter(User.id == user_id).first()


@router.get("/captcha", response_model=CaptchaResponse)
def generate_captcha(request: Request):
    ip = _client_ip(request)
    if _is_rate_limited(f"captcha:{ip}", CAPTCHA_MAX_PER_WINDOW, RATE_LIMIT_WINDOW):
        logger.warning("captcha_rate_limited ip=%s", ip)
        raise HTTPException(status_code=429, detail="Too many captcha requests, try later.")

    cleanup_expired_captchas()
    chars = string.ascii_uppercase + string.digits
    code = "".join(secrets.choice(chars) for _ in range(4))
    captcha_id = str(uuid.uuid4())
    _captcha_store[captcha_id] = {"code": code, "expire": time.time() + 300}
    return CaptchaResponse(
        captcha_id=captcha_id,
        captcha_image=build_captcha_image(code),
        captcha_text=code if settings.CAPTCHA_DEBUG else "",
    )


@router.post("/register", response_model=TokenResponse)
def register(body: UserRegister, request: Request, db: Session = Depends(get_db)):
    ip = _client_ip(request)
    if _is_rate_limited(f"register:{ip}", REGISTER_MAX_PER_WINDOW, RATE_LIMIT_WINDOW):
        logger.warning("register_rate_limited ip=%s username=%s", ip, body.username)
        _audit(db, "register", body.username, ip, "blocked", "rate_limited")
        raise HTTPException(status_code=429, detail="Too many registration attempts, try later.")

    captcha = _captcha_store.pop(body.captcha_id, None)
    if not captcha or float(captcha["expire"]) < time.time():
        logger.info("register_captcha_expired ip=%s username=%s", ip, body.username)
        _audit(db, "register", body.username, ip, "failed", "captcha_expired")
        raise HTTPException(status_code=400, detail="Captcha expired, please refresh.")
    if str(captcha["code"]).upper() != body.captcha_code.upper():
        logger.info("register_captcha_invalid ip=%s username=%s", ip, body.username)
        _audit(db, "register", body.username, ip, "failed", "captcha_invalid")
        raise HTTPException(status_code=400, detail="Captcha is incorrect.")

    pwd_err = validate_password(body.password)
    if pwd_err:
        logger.info("register_password_weak ip=%s username=%s", ip, body.username)
        _audit(db, "register", body.username, ip, "failed", "password_weak")
        raise HTTPException(status_code=400, detail=pwd_err)

    if db.query(User).filter(User.username == body.username).first():
        logger.info("register_duplicate ip=%s username=%s", ip, body.username)
        _audit(db, "register", body.username, ip, "failed", "username_exists")
        raise HTTPException(status_code=400, detail="Username already exists.")

    user = User(username=body.username, password_hash=hash_password(body.password), role="user")
    db.add(user)
    db.commit()
    db.refresh(user)
    logger.info("register_success ip=%s username=%s user_id=%s", ip, user.username, user.id)
    _audit(db, "register", user.username, ip, "ok", "success")
    token = create_token(user.id, user.username, user.role)
    return TokenResponse(access_token=token, username=user.username, role=user.role)


@router.post("/login", response_model=TokenResponse)
def login(body: UserLogin, request: Request, db: Session = Depends(get_db)):
    ip = _client_ip(request)
    if _is_rate_limited(f"login:{ip}", LOGIN_MAX_PER_WINDOW, RATE_LIMIT_WINDOW):
        logger.warning("login_rate_limited ip=%s username=%s", ip, body.username)
        _audit(db, "login", body.username, ip, "blocked", "rate_limited")
        raise HTTPException(status_code=429, detail="Too many login attempts, try later.")

    is_locked, remaining = _is_login_locked(body.username)
    if is_locked:
        logger.warning("login_locked ip=%s username=%s remaining=%s", ip, body.username, remaining)
        _audit(db, "login", body.username, ip, "blocked", "account_locked")
        raise HTTPException(status_code=429, detail=f"Account temporarily locked. Retry in {remaining}s.")

    user = db.query(User).filter(User.username == body.username).first()
    if not user or not verify_password(user.password_hash, body.password):
        fail_count, lock_remaining = _record_login_failure(body.username)
        if lock_remaining > 0:
            logger.warning(
                "login_failed_locked ip=%s username=%s fails=%s lock=%ss",
                ip,
                body.username,
                fail_count,
                lock_remaining,
            )
            _audit(db, "login", body.username, ip, "blocked", "too_many_failures")
            raise HTTPException(status_code=429, detail=f"Account temporarily locked. Retry in {lock_remaining}s.")
        logger.info("login_failed ip=%s username=%s fails=%s", ip, body.username, fail_count)
        _audit(db, "login", body.username, ip, "failed", "invalid_credentials")
        raise HTTPException(status_code=401, detail="Invalid username or password.")

    _clear_login_failure(body.username)
    if not user.password_hash.startswith("pbkdf2_sha256$"):
        user.password_hash = hash_password(body.password)
        db.commit()

    logger.info("login_success ip=%s username=%s user_id=%s", ip, user.username, user.id)
    _audit(db, "login", user.username, ip, "ok", "success")
    token = create_token(user.id, user.username, user.role)
    return TokenResponse(access_token=token, username=user.username, role=user.role)


@router.get("/me", response_model=UserResponse)
def get_me(user: User = Depends(get_current_user)):
    return user
