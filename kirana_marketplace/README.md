# Kirana Mandi

A Flutter marketplace app implementing customer / shopkeeper / admin
flows: name+phone+OTP customer login, phone+OTP shopkeeper login,
env-credential admin login, region-based shop discovery (with
shopkeeper-created areas), a no-photo icon-based product catalog, shop
approval workflow, a cart + order/delivery flow, shopkeeper sales
analytics, and super-admin-managed admin accounts.

This was generated in an environment without the Flutter SDK, so it ships
as `lib/` + `pubspec.yaml` only — you'll do a one-time `flutter create .`
on your machine to generate the Android/iOS platform folders around it.

## ⚠️ Read this first: where does data live, and do I need a database?

**There are now two modes, switched by a single build flag.**

By default (no extra flags), every screen reads and writes a **local
SQLite database that lives only on that one phone**
(`lib/data/local/database_helper.dart`) — no server involved. That's
single-device/demo mode: a shopkeeper's shop and a customer's cart/orders
only exist on that one phone, and a customer's order won't show up on a
different phone running the app.

Pass `--dart-define=API_BASE_URL=https://your-backend-url` (pointing at
the FastAPI backend in `../kirana_backend/`) and the app switches every
repository from its on-device `Sqlite*Repository` implementation to the
matching `Http*Repository` one instead (see `lib/data/remote/` and the
wiring in `lib/main.dart`) — the exact same screens now read/write a
shared Postgres database through the API, so a shopkeeper's shop and a
customer's order are visible across different phones. See
`../kirana_backend/README.md` for deploying that backend (Aiven Postgres
+ Render) and exactly which env vars to pass here to match it.

```bash
flutter run \
  --dart-define=API_BASE_URL=https://kirana-mandi-api.onrender.com \
  --dart-define=ADMIN_ID=owner \
  --dart-define=ADMIN_PASSWORD=ChangeMeNow123
```

This was a deliberate structure from the start — every repository in
`lib/data/repositories/` is written against an abstract interface
(`ShopRepository`, `OrderRepository`, etc.), and `lib/main.dart` binds
either the SQLite or the HTTP implementation of each one behind that same
interface; no screen code needs to know or care which mode is active.

**What this wiring does NOT do:** it's a direct online client, not a
true offline-first sync layer. `Http*Repository` calls fail with a
friendly `NetworkException` when there's no connectivity — they don't
queue the write locally and retry later. The on-device `sync_queue`
table (and the backend's `POST /sync-queue`) exist as the starting point
for that, but nothing drains the queue automatically yet. So: in HTTP
mode, treat "offline support" as "the SQLite mode still exists and still
works fully offline," not as "this app is resilient to spotty
connectivity while also talking to the shared backend."

Also still true regardless of mode: OTP is only as real as your TextBee
setup (see below), and payments aren't in scope (this models "confirm by
phone, shopkeeper accepts", not checkout).

## 1. First-time setup

```bash
cd kirana_marketplace   # folder name kept as-is; app name/branding is "Kirana Mandi"

# Generates android/, ios/, etc. around the existing lib/ and pubspec.yaml
# without touching them (safe to run on an existing project).
flutter create .

flutter pub get
```

## 2. Android location permission (for "use current location")

The shopkeeper's "Use current location" button uses the `geolocator`
package. After `flutter create .`, add this permission to
`android/app/src/main/AndroidManifest.xml`, inside the `<manifest>` tag
(above `<application>`):

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

For iOS, add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to set your shop's location on the map.</string>
```

## 3. Configure secrets (admin login + real OTP SMS)

Nothing sensitive is hardcoded — it's all read at build/run time via
`--dart-define`, in `lib/core/constants/env_config.dart`. Nothing is
required to run in dev mode (admin login just won't work until you set
it, and OTP falls back to the fixed dev code `1234`).

| Variable             | Required for                          |
|----------------------|----------------------------------------|
| `API_BASE_URL`       | Switches the whole app from on-device SQLite to the FastAPI backend (see the top of this README and `../kirana_backend/`). Leave unset for local SQLite mode. |
| `ADMIN_ID`           | Admin login screen. In SQLite mode, checked on-device. In `API_BASE_URL` mode, forwarded to the backend, which checks it against its own `ADMIN_ID` |
| `ADMIN_PASSWORD`     | Same as above, for the password |
| `TEXTBEE_API_KEY`    | Real SMS OTP via textbee.dev. **Only used in SQLite mode** -- in `API_BASE_URL` mode, the backend sends OTPs itself, so set these on the backend instead (see its README) |
| `TEXTBEE_DEVICE_ID`  | Same as above |
| `USE_TEXTBEE_OTP`    | Optional explicit override (`true`/`false`) — auto-enables once both TextBee values above are set, so you usually don't need this |

Run with them, e.g.:

```bash
flutter run \
  --dart-define=ADMIN_ID=owner \
  --dart-define=ADMIN_PASSWORD=ChangeMeNow123 \
  --dart-define=TEXTBEE_API_KEY=your_textbee_api_key \
  --dart-define=TEXTBEE_DEVICE_ID=your_textbee_device_id
```

Or put the same flags (one per line, no quotes) in your IDE's "Additional
run args" / a `dart_defines.txt` you keep out of version control, so you
don't retype them every run. **Never commit real values.**

### Getting TextBee credentials

1. Install the [textbee](https://textbee.dev) Android app on a phone
   that will act as your SMS gateway, and grant SMS permission.
2. In the textbee.dev dashboard, register that device and create an API
   key — you'll get both a **Device ID** and an **API Key**.
3. Pass them as `TEXTBEE_DEVICE_ID` / `TEXTBEE_API_KEY` above.

The app sends via `POST
https://api.textbee.dev/api/v1/gateway/devices/{deviceId}/send-sms` with
the `x-api-key` header — this app previously called the endpoint without
the device id in the path, which textbee's API does not accept; that's
fixed now.

## 4. Try it out

- **Customer**: tap "I am a Customer" → enter your name and phone →
  verify the OTP → you land on Home with a bottom nav: **Home** (browse
  by area), **Search**, **Cart**, **Orders**. Add items to your cart
  from any shop's profile page; the cart groups items by shop. Placing
  an order shows a reminder to call the shop first, then creates the
  order; it starts as "Order Placed" until the shopkeeper accepts it
  in their app.
- **Shopkeeper**: tap "I am a Shopkeeper", enter any 10-digit number
  starting with 6–9, then enter OTP `1234` (fixed dev code unless
  TextBee is configured — see above). First-time login walks you into
  shop setup, where you pick an existing area or **add your own** (the
  same list customers browse and admins manage). Your shop starts as
  **Pending Approval** and won't show to customers until an admin
  approves it. From the dashboard, **Orders** lets you accept/reject
  incoming orders, mark them Preparing → Out for Delivery (attach the
  delivery boy's phone number here — the customer sees it and can call
  them) → Delivered.
- **Admin**: the admin login button is intentionally not on the home
  screen — tap the app logo/icon at the top of the role-select screen to
  reach it. Log in with the `ADMIN_ID` / `ADMIN_PASSWORD` you configured
  above (not a phone number, not an OTP). From there, approve the
  shopkeeper's shop under "Shop Approvals" so it becomes visible to
  customers.
- **No demo data is seeded anymore.** Regions/areas and shops start
  empty — every area comes from an admin or a shopkeeper, and every shop
  comes from a real shopkeeper signup (see "Removed seed data" below).
  Reference/catalog data (product categories, services, the icon
  library) is still seeded so the product-adding UI has something to
  pick from on first launch.

## Removed seed data

Earlier versions of this app seeded 5 demo regions and 4 demo
shops/shopkeepers/products so the customer side had something to browse
immediately. That's gone — a real deployment shouldn't ship with fake
shops in it. If you want a populated environment for a demo/walkthrough,
either use the app normally (sign up a shopkeeper, add an area/shop/
products, approve it as admin) or write a small debug-only script that
calls the same repositories (`ShopRepository.createShop`,
`ProductRepository.createProduct`, etc.) so demo data flows through the
exact same code path as real data.

## OTP delivery

Two `AuthRepository` implementations are wired up for SQLite mode in
`main.dart` (in `API_BASE_URL` mode, `HttpAuthRepository` calls the
backend instead, which does its own textbee.dev integration server-side
-- see `../kirana_backend/README.md`):

- **`DevAuthRepository`** (default): fixed code `1234`, no network call.
  Good for development without any SMS gateway configured.
- **`TextbeeAuthRepository`**: generates a real one-time code, stores it
  locally with a 5-minute expiry, and sends it via the
  [textbee.dev](https://textbee.dev) gateway. Automatically used once
  `TEXTBEE_API_KEY` and `TEXTBEE_DEVICE_ID` are both set (see "Configure
  secrets" above) — no code change needed.

This flow is shared by **both customers and shopkeepers** (customers
previously had no login at all).

In SQLite mode the OTP is generated and checked on-device (`otp_codes`
table) rather than server-side -- fine for an internal MVP. In
`API_BASE_URL` mode this moves server-side automatically (the backend
has its own `otp_codes` table and textbee integration), which is the
hardened path for a real deployment.

## Admin login

Admin login is **not** phone+OTP. It's a single id/password pair you
configure via `--dart-define` (`ADMIN_ID` / `ADMIN_PASSWORD`, see
above). In SQLite mode this is checked entirely on-device against those
build-time values; in `API_BASE_URL` mode the credentials are sent to
the backend instead, which checks them against its own env vars (the
real authorization boundary once a backend exists -- see
`AuthController.loginAdmin` / `HttpAuthRepository.loginWithAdminCredentials`).
Either way, on success a `super_admin` user row is created (once) so the
rest of the app (Manage Admins, ownership checks, etc.) treats this
session like any other admin's. If credentials aren't configured on the
side that's actually checking them, admin login shows a clear
"not configured" message rather than failing silently.

## Cart & Orders

- **Cart** (`lib/features/customer/cart_controller.dart`,
  `cart_repository.dart`): persisted per customer (on-device in SQLite
  mode, server-side via the backend's `cart_items` table in
  `API_BASE_URL` mode), so it survives an app restart. A cart can span
  multiple shops; the Cart screen groups items by shop with a subtotal
  and a **Place Order** button per shop group.
- **Ordering flow**: tapping "Place Order" on a shop group first shows a
  reminder to call the shop and confirm availability (with a one-tap
  Call button), then creates the order. The order starts as **Order
  Placed** and is not final until the shopkeeper accepts it in their
  Orders screen — this mirrors "call and confirm, then the shopkeeper
  agrees" rather than instant e-commerce checkout (there's no payment
  gateway in scope).
- **Order status**: Placed → Accepted → Preparing → Out for Delivery →
  Delivered (or Rejected/Cancelled at the appropriate points). The
  shopkeeper sets the delivery boy's phone number when marking an order
  "Out for Delivery"; the customer's Orders tab shows that number with a
  Call button.
- **Cross-device orders**: in SQLite mode (no `API_BASE_URL`), this only
  works when the customer and shopkeeper are using the same on-device
  database -- see the "read this first" section above. Set
  `API_BASE_URL` to point at a deployed `kirana_backend` and this works
  across separate phones, since `HttpOrderRepository`/
  `HttpCartRepository` are already wired up.

## Offline support, caching, and error handling

- Every read/write goes to a local SQLite database, so browsing,
  cart, and order history all keep working with no network.
- **`ConnectivityService`** (`lib/core/network/connectivity_service.dart`)
  watches device connectivity and powers `OfflineBanner`, shown at the
  top of the shopkeeper and admin dashboards whenever there's no network.
- **`sync_queue` table** — every local write (shop/product create or
  update, daily sales entries) also appends a row here via
  `SyncQueueRepository`. It's inert today; once the app talks to a real
  API, a background worker can drain this table (oldest `synced = 0`
  first) and push each change up.
- **`friendlyErrorMessage()` / `runGuarded()`**
  (`lib/core/errors/exceptions.dart`, `lib/core/utils/run_guarded.dart`) —
  every mutating action (save shop, add product, log a sale, add an
  admin, place/update an order, send OTP) is wrapped so failures show a
  short, friendly message instead of a raw exception or a silent no-op.
  `OfflineException` / `NetworkException` give specific copy for
  connectivity vs. server errors once real network calls are involved.
- The customer product search bar previously showed **invisible white
  text on a white background** — the app's global text-field theme
  fills every field white, and the search bar also forced white text for
  contrast against the AppBar. Fixed by explicitly turning the fill off
  for that one field (`lib/features/customer/product_search_screen.dart`).

## Architecture notes

- **Data layer / repository pattern** (`lib/data/repositories`, plus
  `lib/data/remote/` for the HTTP implementations): every repository is
  defined as an abstract interface with both a `Sqlite*` and an `Http*`
  implementation. Screens depend only on the interface;
  `lib/main.dart` binds whichever pair matches `EnvConfig.useRemoteApi`
  (see the top of this README).
- **`ApiClient`** (`lib/data/remote/api_client.dart`): the one place that
  knows the backend's base URL, attaches the bearer token, and maps HTTP
  status codes onto the same exception types (`NetworkException`,
  `ValidationException`, etc.) the SQLite repositories already throw --
  so `runGuarded()` and friendly error messages work identically in
  either mode.
- **No image uploads**: products/shops reference a bundled Material icon
  by string id (`lib/core/constants/icon_registry.dart`) rather than a
  photo.
- **Ownership checks**: SQLite-mode repositories that mutate a shop,
  product, or order take a `requestingUserId` and throw
  `UnauthorizedException` if it doesn't match the resource owner -- a
  UX safety net only. In `API_BASE_URL` mode, the backend independently
  re-enforces every one of these checks server-side using the
  authenticated session (see `kirana_backend/app/routers/`), which is
  the check that actually matters once there's a real API.
- **Admin accounts**: the single configured admin logs in via
  id/password (see above). Additional admins can still be added by
  phone number via **Admin Dashboard → Manage Admins** (only super
  admins can see/use this) — those secondary admins would need their own
  login path wired up if you use this feature (not built in this pass).
- **Persistent login**: `SessionStorage` (shared_preferences) persists
  the logged-in user id and, in `API_BASE_URL` mode, the bearer token.
  `SplashScreen` restores the session on cold start and routes straight
  to the right dashboard (customer/shopkeeper/admin);
  `AuthController.logout()` clears both, and the Cart is cleared from
  memory on logout so a different customer on the same device doesn't
  see the previous one's cart.
- **Areas/regions**: a shopkeeper can pick an existing area or type a
  new one during shop setup (`RegionRepository.findOrCreateByName`) —
  new areas are added to the same table admins manage, so they
  immediately show up everywhere areas are listed.
- **Dark theme**: toggle lives in Settings, persisted via
  `ThemeController`. Known limitation: a handful of pre-login screens
  (role select, region tiles) use hardcoded light-mode colors rather than
  theme-derived ones, so they won't re-skin in dark mode — the
  shopkeeper/admin/customer dashboards and all dialogs/forms do.

## Shopkeeper analytics & sales

- **Today's Sales** (`lib/features/shopkeeper/daily_sales_screen.dart`):
  log items sold today (pick from your catalog or type free text),
  quantity, and price — the screen totals revenue live as you add lines.
- **Analytics** (`lib/features/shopkeeper/analytics_screen.dart`): a
  Daily/Weekly/Monthly filter drives a revenue bar chart (via
  [fl_chart](https://pub.dev/packages/fl_chart)) plus a top-selling-items
  list, aggregated from the `sale_items` table (on-device in SQLite
  mode; computed server-side from the backend's flat `sale_items` table
  in `API_BASE_URL` mode -- see `kirana_backend`'s `/sales/series` and
  `/sales/top-products` endpoints).
- **Calls** (`lib/features/shopkeeper/calls_screen.dart`): every time a
  customer taps "Call Shop" on a shop profile, a row is logged to
  `call_logs`. This screen lists them, grouped by day.
- **Orders** (`lib/features/shopkeeper/shopkeeper_orders_screen.dart`):
  accept/reject incoming orders and advance their status through to
  delivery (see "Cart & Orders" above).

## What's not built (natural next steps)

- **True offline-first sync in `API_BASE_URL` mode** — see the
  "read this first" section above. `Http*Repository` calls fail
  outright when offline rather than queuing for retry; the `sync_queue`
  table/endpoint is a starting point but nothing drains it automatically.
- Push notifications for order status changes (currently the customer
  has to open the Orders tab to see updates).
- Payment gateway / in-app checkout (out of scope — this models a
  "confirm by phone, shopkeeper accepts" flow, not e-commerce payment).
- Google Maps SDK embed (currently "View on Maps" opens the device's
  Google Maps app via a URL — avoids requiring an API key for the MVP).
- Server-side database migrations for the backend (it currently creates
  tables via `Base.metadata.create_all()` -- fine to start, but switch to
  Alembic once the schema needs to evolve in production; see
  `kirana_backend/README.md`).
- A login path for secondary admins added via "Manage Admins" (today
  only the single configured admin has a working login screen, in
  either mode).
