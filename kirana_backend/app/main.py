import logging

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .database import Base, engine, run_startup_migrations
from .routers import admin, auth, catalog, deploy, orders, shops, sync

logging.basicConfig(level=logging.INFO)
settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # create_all is idempotent and fine for this app's simple schema. For
    # a schema that changes over time, switch to Alembic migrations
    # instead (see README "Database migrations").
    Base.metadata.create_all(bind=engine)
    # Additive column migrations for databases that already existed
    # before those columns were added to the model (see database.py).
    run_startup_migrations()
    yield


app = FastAPI(
    title="Kirana Mandi API",
    description=(
        "Backend for the Kirana Mandi Flutter app. See the top-level "
        "README for how this replaces the mobile app's local SQLite "
        "repositories once wired up."
    ),
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", tags=["health"])
def root() -> dict:
    return {"status": "ok", "service": "kirana-mandi-api"}


@app.get("/health", tags=["health"])
def health() -> dict:
    return {
        "status": "ok",
        "admin_login_configured": settings.admin_login_configured,
        "textbee_configured": settings.textbee_configured,
    }


app.include_router(auth.router)
app.include_router(catalog.router)
app.include_router(shops.router)
app.include_router(orders.router)
app.include_router(admin.router)
app.include_router(sync.router)
app.include_router(deploy.router)
