from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://dealsapp:dealsapp@localhost:5433/dealsapp"
    redis_url: str = "redis://localhost:6380/0"

    class Config:
        env_file = ".env"


settings = Settings()
