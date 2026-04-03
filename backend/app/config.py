from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_ENV: str = "development"
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "root"
    DB_PASSWORD: str = ""
    DB_NAME: str = "smart_agriculture"
    SECRET_KEY: str = "please_set_secret_key_in_env"
    TOKEN_EXPIRE_HOURS: int = 168
    CORS_ORIGINS: str = "http://localhost:3000,http://127.0.0.1:3000"
    CAPTCHA_DEBUG: bool = False
    AUTH_RATE_LIMIT_WINDOW: int = 600
    AUTH_CAPTCHA_MAX_PER_WINDOW: int = 30
    AUTH_REGISTER_MAX_PER_WINDOW: int = 10
    AUTH_LOGIN_MAX_PER_WINDOW: int = 30
    AUTH_LOGIN_FAIL_MAX: int = 5
    AUTH_LOGIN_LOCK_SECONDS: int = 900
    SIMULATE_INTERVAL: int = 5  # seconds
    WEATHER_API_BASE: str = "https://api.open-meteo.com/v1/forecast"
    WEATHER_GEOCODE_API_BASE: str = "https://geocoding-api.open-meteo.com/v1/search"
    OPENCLAW_API_BASE: str = "https://api.openclaw.example/v1"
    OPENCLAW_API_KEY: str = ""
    OPENCLAW_ENABLED: bool = False
    HUAWEI_WATCH_TOKENS: str = ""
    XIAOYI_SHARED_SECRET: str = ""

    @property
    def cors_origins_list(self) -> list[str]:
        origins = [item.strip() for item in self.CORS_ORIGINS.split(",") if item.strip()]
        return origins or ["http://localhost:3000"]

    class Config:
        env_file = ".env"


settings = Settings()


def _validate_security_settings(cfg: Settings) -> None:
    env = cfg.APP_ENV.lower().strip()
    if env in {"prod", "production"}:
        default_key = "please_set_secret_key_in_env"
        if cfg.SECRET_KEY == default_key or len(cfg.SECRET_KEY) < 32:
            raise RuntimeError(
                "In production, SECRET_KEY must be set to a random string with at least 32 characters."
            )


_validate_security_settings(settings)
