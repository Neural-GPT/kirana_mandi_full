# Multi-Tenant / White-Label Refactor — Summary

This documents what changed to turn Kirana Mandi into a multi-tenant
backend + white-labelable Flutter app, organized by the phases in the
original brief.

## Phase 1 — Backend (FastAPI + Postgres)

- **`kirana_backend/app/models.py`** — `Shop` gained white-label columns:
  `logo_url`, `banner_url`, `primary_color`, `secondary_color`, and a
  unique `shop_code` (auto-generated 8-char code).
- **`kirana_backend/app/schemas.py`** — those fields added to
  `ShopCreate`/`ShopUpdate`/`ShopOut`; new `ShopBrandingOut` and
  `ShopCodeLookupOut` schemas.
- **`kirana_backend/app/routers/shops.py`**:
  - `GET /shops/{shop_id}/branding` — the white-labeling config endpoint
    from the brief (`shop_name, logo_url, primary_color, secondary_color,
    region_id, contact_number, status`, plus `shop_code`). Public — no
    auth — so a fresh white-label install can paint its first screen
    before anyone logs in.
  - `GET /shops/by-code/{shop_code}` — resolves a shopkeeper-shared Shop
    Code to a `shop_id`, for the "Dynamic / On-the-Fly" flow.
  - `list_products` and `get_shop` now depend on `verify_tenant_scope`.
- **`kirana_backend/app/deps.py`** — new `verify_tenant_scope` dependency:
  reads an optional `X-Shop-ID` header and 403s if it's present but
  doesn't match the `shop_id` in the URL. Additive — omitting the header
  (every non-white-label client) changes nothing.
- **`kirana_backend/app/database.py`** + **`main.py`** — since this
  project has no Alembic, added `run_startup_migrations()`: an additive,
  idempotent column-adder that runs in the FastAPI lifespan so an
  existing SQLite/Postgres database picks up the new `shops` columns
  (and backfills `shop_code` for pre-existing rows) without a manual
  migration step.

## Phase 2 — Shopkeeper Portal

- **`shop_setup_screen.dart`** — onboarding/edit form gained a
  "White-Label Branding" section: logo/banner URL fields and a 9-swatch
  brand-color picker (no picker plugin dependency). Shows the shop's
  Shop Code (read-only) once the shop exists.
- **`app_deployment_screen.dart`** (new) — the "App Generator &
  Configurator", reachable from a new **App Deployment** tile on the
  shopkeeper dashboard. Two sections:
  - **Dynamic / On-the-Fly** — the shop's Shop Code and a shareable deep
    link (`kiranamandi://shop/<code>`), each with a copy button.
  - **Build Automation Config** — a generated `build_config.json`
    (`SHOP_ID`, `APP_NAME`, `PRIMARY_COLOR`, `SECONDARY_COLOR`,
    `API_BASE_URL`) and the equivalent `flutter build apk --dart-define=...`
    command, both copyable.

## Phase 3 — Customer App (White-Labeled UI)

- **`core/constants/env_config.dart`** — added `SHOP_ID`, `APP_NAME`,
  `PRIMARY_COLOR`, `SECONDARY_COLOR` dart-defines and `isWhiteLabelBuild`.
- **`core/theme/shop_theme_controller.dart`** (new) — the
  `TenantProvider`/`ShopThemeController`. Resolves a shop lock from
  either source:
  - **Build-time**: `EnvConfig.shopId` (permanent for that install).
  - **Runtime** ("Dynamic" mode): a Shop Code entered via the new
    `ShopEntryScreen`, persisted in `SharedPreferences` so it survives
    restarts, changeable via `clearLock()`.
  Exposes `light()`/`dark()` `ThemeData` built from the shop's colors
  (`core/theme/app_theme.dart` gained `AppTheme.branded(...)` for this).
- **`data/repositories/tenant_repository.dart`** (new) — abstract
  `TenantRepository` + `HttpTenantRepository`/`SqliteTenantRepository`,
  following the existing repository pattern.
- **`data/remote/api_client.dart`** — `setTenantShopId()` attaches
  `X-Shop-ID` to every request once locked, matching the backend guard.
- **`customer_shell_screen.dart` / `customer_home_screen.dart`** — when
  locked to a shop, the Home tab skips region/shop discovery entirely
  and renders that shop's catalog directly (reusing `ShopProfileScreen`).
- **`product_search_screen.dart`** — search is scoped to the locked shop
  only, so a cross-shop search can't leak other tenants' products into a
  white-label build.
- **`cart_controller.dart`** — `restrictToShop(shopId)` rejects
  add-to-cart/checkout for any other shop as a client-side mirror of the
  backend's tenant guard.
- **`cart_screen.dart`** — in locked mode, the shopkeeper's phone is
  dialed automatically right after an order is placed.
- **`shop_entry_screen.dart`** (new) — "Have a shop code or shop link?"
  entry point (linked from `role_select_screen.dart`) for the Dynamic
  mode.

## GitHub Actions

- **`.github/workflows/build_apk.yml`** (new) — builds a shop-specific
  APK via `--dart-define`, either:
  - automatically, once per shop listed in `shops.json` at the repo root
    (a matrix build), whenever that file changes, or
  - manually via `workflow_dispatch`, pasting in one shop's `SHOP_ID`,
    `APP_NAME`, `PRIMARY_COLOR` (exactly what the App Deployment screen
    shows).
  `API_BASE_URL` comes from a repo-level Actions variable, shared across
  every shop. An example `shops.json` is included as a starting point.

## Local SQLite (offline/demo mode)

- **`data/local/database_helper.dart`** — DB version bumped to 4; new
  `shops` columns added both to fresh installs (`_onCreate`) and to
  existing databases (`_createV4Columns`, which also backfills
  `shop_code` for pre-existing rows).
- **`data/repositories/shop_repository.dart`** (`SqliteShopRepository`)
  — `createShop` now generates a unique `shop_code`, mirroring the
  backend's generator.

## Testing notes

No network access was available in this environment, so backend changes
were verified with `python -m py_compile` on every touched file (all
pass) rather than a live server run, and the Flutter changes were
reviewed file-by-file (plus a full diff against the original project)
rather than run through `flutter analyze`/`flutter test`. Before
deploying:

- Backend: run normally (`uvicorn app.main:app`) against a copy of your
  dev database first — `run_startup_migrations()` only ever adds
  columns, but it's worth confirming the migration once on a copy.
- Flutter: `flutter pub get && flutter analyze` to catch anything an
  environment without the Flutter SDK couldn't.
- Try the two white-label paths end-to-end: create a shop, set a brand
  color, then (a) use its Shop Code via **Have a shop code or shop
  link?** on the role-select screen, and (b) build once with
  `--dart-define=SHOP_ID=...` and confirm the app skips straight to that
  shop.
