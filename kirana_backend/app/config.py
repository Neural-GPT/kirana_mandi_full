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

    # --- White-label APK generation (see routers/deploy.py) ---
    # A fine-grained GitHub personal access token (or a fine-grained
    # token from a GitHub App) with "Actions: read and write" +
    # "Contents: read and write" on github_repo -- write is needed for
    # both triggering the build workflow and publishing/overwriting the
    # per-shop Release it creates. Leave blank to disable "Generate My
    # App" (the endpoint returns 503 rather than failing oddly).
    github_token: str = ""
    # "owner/repo", e.g. "sharma-kirana/kirana-mandi".
    github_repo: str = ""
    github_workflow_file: str = "build_apk.yml"
    # The branch/ref the workflow file lives on -- almost always "main".
    github_workflow_ref: str = "main"

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_allow_origins.split(",") if o.strip()]

    @property
    def admin_login_configured(self) -> bool:
        return bool(self.admin_id and self.admin_password)

    @property
    def textbee_configured(self) -> bool:
        return bool(self.textbee_api_key and self.textbee_device_id)

    @property
    def github_deploy_configured(self) -> bool:
        return bool(self.github_token and self.github_repo)


@lru_cache
def get_settings() -> Settings:
    return Settings()
