from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings

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
