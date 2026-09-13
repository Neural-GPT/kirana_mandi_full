# Kirana Mandi API

FastAPI backend for the Kirana Mandi Flutter app: OTP auth (customer +
shopkeeper, via textbee.dev), env-credential admin login, regions/
categories/services, shops (with approval workflow), products, cart,
orders (with the accept/reject/status flow), sales analytics, and call
logs.

Mirrors the data model and business rules already implemented in the
Flutter app's local SQLite layer (`kirana_marketplace/lib/data/`) so
swapping the mobile app's `Sqlite*Repository` classes for `Http*`
equivalents calling this API is a like-for-like mapping.

## Local development

```bash
cd kirana_backend
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env             # defaults to a local SQLite file --
                                  # nothing else required to run it

python -m app.seed               # seeds shop/product categories + services
                                  # (no demo shops/regions -- see note below)

uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000/docs` for interactive Swagger docs generated
from the code (every endpoint, request/response shape, and auth
requirement is listed there).

No demo shops or regions are seeded, matching the Flutter app's own
`seed_data.dart` — every area comes from an admin or a shopkeeper, and
every shop comes from a real shopkeeper signup. `python -m app.seed`
only adds reference data (categories, services) so the product-adding UI
has something to pick from.

## Production: Aiven Postgres + Render

### 1. Create the Aiven Postgres database

1. In the Aiven console, create a **PostgreSQL** service (the free/
   starter plan is enough to begin with).
2. Once it's running, open its **Overview** tab and copy the **Service
   URI** — it looks like:
   ```
   postgres://avnadmin:PASSWORD@your-service-name.aivencloud.com:12345/defaultdb?sslmode=require
   ```
3. That's your `DATABASE_URL` — paste it in unmodified. `app/database.py`
   automatically rewrites the `postgres://` scheme to
   `postgresql+psycopg2://` (SQLAlchemy's psycopg2 dialect needs that
   exact scheme; Aiven, Render, and most managed Postgres providers hand
   out the shorter `postgres://` form) and passes `sslmode=require`,
   which Aiven requires.

### 2. Deploy to Render

**Option A — Blueprint (recommended):** push this `kirana_backend/`
folder to a Git repo, then in Render: **New +** → **Blueprint**, point
it at the repo. `render.yaml` in this folder defines the service,
build/start commands, and health check; you'll be prompted to fill in
the env vars marked `sync: false`.

**Option B — manual Web Service:**
1. **New +** → **Web Service**, connect your repo, set the root
   directory to `kirana_backend` if the repo contains other folders too
   (e.g. this ships alongside `kirana_marketplace/` in the same zip).
2. **Build Command:** `pip install -r requirements.txt`
3. **Start Command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. **Environment** tab — add:
   - `DATABASE_URL` — the Aiven URI from step 1
   - `JWT_SECRET` — a long random string (Render can generate one, or
     run `python -c "import secrets; print(secrets.token_urlsafe(48))"`)
   - `ADMIN_ID`, `ADMIN_PASSWORD` — must match what you pass to the
     Flutter app's `--dart-define=ADMIN_ID=...` / `ADMIN_PASSWORD=...`
   - `TEXTBEE_API_KEY`, `TEXTBEE_DEVICE_ID` — same values as the
     Flutter app's `--dart-define`s (see the mobile app's README)
   - `CORS_ALLOW_ORIGINS` — `*` is fine for a mobile-only client

### 3. Point the Flutter app at it

Done — the mobile app now has `Http*Repository` implementations of every
repository interface (`lib/data/remote/`), an `ApiClient` that attaches
the bearer token and maps HTTP errors onto the app's existing exception
types, and `main.dart` switches every repository from the on-device
`Sqlite*` implementation to the matching `Http*` one whenever
`API_BASE_URL` is set:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://kirana-mandi-api.onrender.com \
  --dart-define=ADMIN_ID=owner \
  --dart-define=ADMIN_PASSWORD=ChangeMeNow123
```
(`ADMIN_ID`/`ADMIN_PASSWORD` here only need to match what you set as this
backend's env vars in step 2 — the app forwards them to `POST
/auth/admin/login` rather than checking them on-device once
`API_BASE_URL` is set. `TEXTBEE_API_KEY`/`TEXTBEE_DEVICE_ID` are no
longer needed on the mobile app side either in this mode, since OTP
sending happens server-side.)

Leave `API_BASE_URL` unset and the app falls back to on-device SQLite
(single-device/offline demo mode) exactly as before — nothing else
changes. See the mobile app's own README for the full picture.

**Known simplification:** the mobile app's `Http*Repository` classes call
this API directly and surface a `NetworkException` on failure — they
don't queue failed writes for retry the way true offline-first sync
would. The on-device `sync_queue` table this backend has an endpoint
for (`POST /sync-queue`) exists for that purpose but isn't wired up to
retry automatically yet; that's the natural next increment if you need
the app to keep working through flaky connectivity while talking to a
live backend.

### Database migrations

This project creates tables via `Base.metadata.create_all()` on startup
(see `app/main.py`), which is fine to get started and for a schema that
doesn't change. Once you're iterating on the schema in production,
switch to [Alembic](https://alembic.sqlalchemy.org/) migrations instead
so schema changes are tracked and reversible rather than silently
auto-created.

## API overview

All endpoints are documented interactively at `/docs`. Rough shape:

| Area | Endpoints |
|---|---|
| Auth | `POST /auth/otp/send`, `POST /auth/otp/verify`, `POST /auth/admin/login`, `GET /auth/me` |
| Catalog | `GET/POST /regions`, `GET/PUT /regions/{id}`, `PATCH /regions/{id}/active`, `GET/POST/PATCH /categories`, `GET/POST/PUT/PATCH /services`, `GET/POST/PATCH /icons` |
| Shops | `POST /shops`, `GET /shops/mine`, `GET /shops/search`, `GET/PUT /shops/{id}`, `PATCH /shops/{id}/availability`, `PUT /shops/{id}/services`, `GET /regions/{id}/shops`, `GET/PATCH /admin/shops...` |
| Products | `GET/POST /shops/{id}/products`, `GET/PUT/DELETE /products/{id}`, `GET /products/search`, `GET /admin/products` |
| Cart | `GET/POST /cart`, `/cart/items` |
| Orders | `POST /orders/checkout`, `GET /orders/mine`, `GET /orders/{id}`, `GET /shops/{id}/orders`, `PATCH /orders/{id}/status`, `POST /orders/{id}/cancel` |
| Sales & calls | `POST/GET /shops/{id}/sales`, `.../revenue`, `.../series`, `.../top-products`, `POST /calls`, `GET /shops/{id}/calls`, `.../calls/count` |
| Admin | `GET /admin/stats`, `GET /admin/users`, `GET/POST/DELETE /admin/admins` |

### Auth model

- Customer/shopkeeper: `POST /auth/otp/send` → SMS (or `debug_otp` in
  the response if textbee isn't configured) → `POST /auth/otp/verify`
  with the code → JWT access token (30-day expiry by default).
- Admin: `POST /auth/admin/login` with the env-configured id/password →
  JWT. Additional admins can be registered by an existing super_admin
  via `POST /admin/admins` (phone number), after which that phone can
  log in via the normal OTP endpoint with `role="admin"`.
- Every other endpoint expects `Authorization: Bearer <token>`.
  Ownership is enforced server-side (a shopkeeper can only modify their
  own shop/products/orders; admins can act on anything) — this is the
  real enforcement the mobile app's on-device checks were only ever a
  UX safety net for.

## Project layout

```
app/
  main.py          FastAPI app, CORS, router registration, startup table creation
  config.py        Settings from environment variables
  database.py      SQLAlchemy engine/session (Aiven URI normalization)
  models.py        SQLAlchemy ORM models (mirrors the mobile app's SQLite schema)
  schemas.py       Pydantic request/response models
  security.py      JWT create/decode
  deps.py          get_current_user / require_roles dependencies
  constants.py     Role names, order status machine
  textbee.py       SMS sending via textbee.dev
  seed.py          Reference-data seeding (categories/services only)
  routers/
    auth.py        OTP + admin login
    catalog.py     Regions, categories, services
    shops.py       Shops + products
    orders.py      Cart + orders
    admin.py       Admin account management
    sync.py        Sales, call logs, optional sync-queue endpoint
```
