"""
All configuration comes from environment variables so nothing sensitive
lives in source control. In production (Render) these are set in the
service's Environment tab; locally, copy `.env.example` to `.env` and
fill it in -- `python-dotenv` loads it automatically via pydantic-settings.
"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- Database (Aiven Postgres in production) ---
    # Aiven gives you a URI like:
    #   postgres://avnadmin:PASSWORD@HOST:PORT/defaultdb?sslmode=require
    # SQLAlchemy needs the "postgresql+psycopg2://" scheme instead of
    # "postgres://" -- see database.py, which rewrites this automatically
    # so you can paste Aiven's URI here unmodified.
    database_url: str = "sqlite:///./dev.db"

    # --- Auth ---
    jwt_secret: str = "dev-secret-change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 30  # 30 days

    # --- Admin login (matches the Flutter app's EnvConfig) ---
    admin_id: str = ""
    admin_password: str = ""

    # --- OTP delivery ---
    # If either is blank, OTPs are generated but not actually sent --
    # useful for local development (the code is returned in the API
    # response's `debug_otp` field, which is only ever populated when
    # textbee isn't configured -- see routers/auth.py).
    textbee_api_key: str = ""
    textbee_device_id: str = ""
    otp_validity_minutes: int = 5

    # --- CORS ---
    # Comma-separated list of allowed origins. "*" is fine for a mobile
    # app (no browser cookies involved) but tighten this if you add a
    # web/admin dashboard with cookie-based auth later.
    cors_allow_origins: str = "*"

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_allow_origins.split(",") if o.strip()]

    @property
    def admin_login_configured(self) -> bool:
        return bool(self.admin_id and self.admin_password)

    @property
    def textbee_configured(self) -> bool:
        return bool(self.textbee_api_key and self.textbee_device_id)


@lru_cache
def get_settings() -> Settings:
    return Settings()
