# Kirana Mandi

Two folders:

- **`kirana_marketplace/`** — the Flutter mobile app. See its own
  `README.md` for setup, environment variables (`--dart-define` for
  admin login + TextBee OTP), and a feature-by-feature rundown of what's
  implemented.
- **`kirana_backend/`** — the FastAPI backend (Aiven Postgres in
  production, deployable on Render). See its own `README.md` for local
  dev setup and step-by-step Aiven + Render deployment instructions.

## Current state, in one paragraph

The backend is complete and independently testable (run it locally and
open `/docs`), covering the same data model and rules as the mobile
app's local SQLite layer: OTP auth, admin login, regions/shops/products,
cart/orders with the accept-reject-deliver flow, sales, and call logs.
**The mobile app does not call it yet** — it still reads/writes its
on-device SQLite database directly, via `Sqlite*Repository` classes
registered in `kirana_marketplace/lib/main.dart`. Wiring the two
together means writing `Http*Repository` implementations of the same
abstract interfaces (`ShopRepository`, `OrderRepository`, etc.) that call
this API with a bearer token, and swapping them in via `main.dart` —
no screen code needs to change. That's the natural next step once
you've deployed the backend and are ready to make the app multi-device.
