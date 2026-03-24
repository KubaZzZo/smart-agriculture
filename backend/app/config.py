from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "root"
    DB_PASSWORD: str = "1025"
    DB_NAME: str = "smart_agriculture"
    SECRET_KEY: str = "smart_agriculture_secret_2024"
    SIMULATE_INTERVAL: int = 5  # seconds

    class Config:
        env_file = ".env"


settings = Settings()
