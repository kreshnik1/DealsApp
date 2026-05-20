from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://dealsapp:dealsapp@localhost:5433/dealsapp"
    redis_url: str = "redis://localhost:6380/0"
    allowed_origins: list[str] = ["*"]

    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 1440
    refresh_token_expire_days: int = 30

    model_config = {"env_file": ".env"}


settings = Settings()
