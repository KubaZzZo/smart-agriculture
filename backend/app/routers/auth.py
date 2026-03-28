import hashlib
import time
import json
import base64
import random
import string
import re
import uuid
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User
from ..schemas import UserRegister, UserLogin, TokenResponse, UserResponse, CaptchaResponse
from ..config import settings

router = APIRouter()

SECRET_KEY = settings.SECRET_KEY

# 验证码存储 {captcha_id: {"code": str, "expire": float}}
_captcha_store: dict = {}


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def create_token(user_id: int, username: str, role: str) -> str:
    payload = {
        "user_id": user_id,
        "username": username,
        "role": role,
        "exp": int(time.time()) + 86400 * 7,  # 7天过期
    }
    payload_str = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode()
    sig = hashlib.sha256(f"{payload_str}.{SECRET_KEY}".encode()).hexdigest()[:16]
    return f"{payload_str}.{sig}"


def verify_token(token: str) -> dict:
    try:
        parts = token.split(".")
        if len(parts) != 2:
            return None
        payload_str, sig = parts
        expected_sig = hashlib.sha256(f"{payload_str}.{SECRET_KEY}".encode()).hexdigest()[:16]
        if sig != expected_sig:
            return None
        payload = json.loads(base64.urlsafe_b64decode(payload_str))
        if payload.get("exp", 0) < time.time():
            return None
        return payload
    except Exception:
        return None


def validate_password(password: str) -> str | None:
    """校验密码强度，返回错误信息或 None"""
    if len(password) < 8:
        return "密码长度至少8位"
    return None


def cleanup_expired_captchas():
    """清理过期验证码"""
    now = time.time()
    expired = [k for k, v in _captcha_store.items() if v["expire"] < now]
    for k in expired:
        del _captcha_store[k]


def get_current_user(authorization: str = Header(None), db: Session = Depends(get_db)) -> User:
    if not authorization:
        raise HTTPException(status_code=401, detail="未登录")
    token = authorization.replace("Bearer ", "")
    payload = verify_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="登录已过期")
    user = db.query(User).filter(User.id == payload["user_id"]).first()
    if not user:
        raise HTTPException(status_code=401, detail="用户不存在")
    return user


@router.get("/captcha", response_model=CaptchaResponse)
def generate_captcha():
    """生成随机验证码"""
    cleanup_expired_captchas()
    # 生成4位随机验证码（字母+数字混合）
    chars = string.ascii_uppercase + string.digits
    code = "".join(random.choices(chars, k=4))
    captcha_id = str(uuid.uuid4())
    _captcha_store[captcha_id] = {
        "code": code,
        "expire": time.time() + 300,  # 5分钟过期
    }
    return CaptchaResponse(captcha_id=captcha_id, captcha_text=code)


@router.post("/register", response_model=TokenResponse)
def register(body: UserRegister, db: Session = Depends(get_db)):
    # 1. 验证码校验
    captcha = _captcha_store.pop(body.captcha_id, None)
    if not captcha:
        raise HTTPException(status_code=400, detail="验证码已过期，请刷新")
    if captcha["expire"] < time.time():
        raise HTTPException(status_code=400, detail="验证码已过期，请刷新")
    if captcha["code"].upper() != body.captcha_code.upper():
        raise HTTPException(status_code=400, detail="验证码错误")

    # 2. 密码强度校验
    pwd_err = validate_password(body.password)
    if pwd_err:
        raise HTTPException(status_code=400, detail=pwd_err)

    # 3. 用户名重复检查
    if db.query(User).filter(User.username == body.username).first():
        raise HTTPException(status_code=400, detail="用户名已存在")

    user = User(
        username=body.username,
        password_hash=hash_password(body.password),
        role="user",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_token(user.id, user.username, user.role)
    return TokenResponse(access_token=token, username=user.username, role=user.role)


@router.post("/login", response_model=TokenResponse)
def login(body: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == body.username).first()
    if not user or user.password_hash != hash_password(body.password):
        raise HTTPException(status_code=401, detail="用户名或密码错误")
    token = create_token(user.id, user.username, user.role)
    return TokenResponse(access_token=token, username=user.username, role=user.role)


@router.get("/me", response_model=UserResponse)
def get_me(user: User = Depends(get_current_user)):
    return user
