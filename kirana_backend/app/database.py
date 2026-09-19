import logging
from collections.abc import Generator

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()


def _normalize_db_url(url: str) -> str:
    # Aiven (and Render's own Postgres, and Heroku-style URIs generally)
    # hand out "postgres://..." but SQLAlchemy's psycopg2 dialect wants
    # "postgresql+psycopg2://...". Rewriting here means you can paste
    # Aiven's connection string into DATABASE_URL unmodified.
    if url.startswith("postgres://"):
        return url.replace("postgres://", "postgresql+psycopg2://", 1)
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+psycopg2://", 1)
    return url


_is_sqlite = settings.database_url.startswith("sqlite")
_connect_args = (
    {"check_same_thread": False}
    if _is_sqlite
    else {
        # Aiven requires TLS; psycopg2 also picks this up from the URI's
        # `sslmode=require` query param, but being explicit here means
        # it still works if that param gets stripped off somewhere.
        "sslmode": "require"
    }
)

engine = create_engine(
    _normalize_db_url(settings.database_url),
    connect_args=_connect_args,
    pool_pre_ping=True,  # avoids "server closed the connection" after idle periods
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# --- Lightweight auto-migration ---------------------------------------
# This project doesn't use Alembic (see main.py's lifespan comment), and
# Base.metadata.create_all() only creates tables that don't exist yet --
# it never ALTERs an existing table when a new column is added to a
# model. That's fine for brand-new deployments but breaks any database
# that already has data (e.g. a shop owner's dev.db, or the shared Aiven
# Postgres instance once it's live) the moment a migration like the
# white-label branding columns below ships. Rather than pull in a full
# migration framework for a single-table, additive change, this adds any
# missing columns by hand at startup -- safe to run every time (it only
# ever ADDs, never drops/alters existing columns) and works the same way
# against both SQLite (dev) and Postgres (prod).
_SHOP_COLUMN_MIGRATIONS: dict[str, str] = {
    "logo_url": "VARCHAR",
    "banner_url": "VARCHAR",
    "primary_color": "VARCHAR",
    "secondary_color": "VARCHAR",
    "shop_code": "VARCHAR",
}


def run_startup_migrations() -> None:
    inspector = inspect(engine)
    if "shops" not in inspector.get_table_names():
        return  # fresh database -- create_all() will create it with every column already present

    existing_columns = {col["name"] for col in inspector.get_columns("shops")}
    missing = {
        name: col_type
        for name, col_type in _SHOP_COLUMN_MIGRATIONS.items()
        if name not in existing_columns
    }
    if not missing:
        return

    with engine.begin() as conn:
        for name, col_type in missing.items():
            logger.info("Migrating: adding shops.%s (%s)", name, col_type)
            conn.execute(text(f"ALTER TABLE shops ADD COLUMN {name} {col_type}"))

        if "shop_code" in missing:
            # Backfill existing rows with a generated code (can't rely on
            # the column default -- that only applies to NEW inserts) and
            # then enforce uniqueness so future lookups by code are safe.
            from .models import _shop_code  # local import: avoids a
            # models -> database -> models circular import at module load

            rows = conn.execute(text("SELECT id FROM shops WHERE shop_code IS NULL")).fetchall()
            used: set[str] = set()
            for (shop_id,) in rows:
                code = _shop_code()
                while code in used:
                    code = _shop_code()
                used.add(code)
                conn.execute(
                    text("UPDATE shops SET shop_code = :code WHERE id = :id"),
                    {"code": code, "id": shop_id},
                )
            if not _is_sqlite:
                conn.execute(text("ALTER TABLE shops ADD CONSTRAINT uq_shops_shop_code UNIQUE (shop_code)"))
            # SQLite can't add a UNIQUE constraint to an existing table
            # without a full table rebuild; the application layer
            # (shops.py's code generator retries on collision) already
            # guards against duplicates for new rows, which is good
            # enough for the SQLite dev database.
