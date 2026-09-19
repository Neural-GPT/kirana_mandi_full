# Performance notes

Concrete changes made in this pass, plus what's still worth doing.

## Done

- **Smaller, faster-installing APKs**: `android/app/build.gradle.kts`
  now enables `isMinifyEnabled` + `isShrinkResources` for release builds
  (R8 code shrinking/obfuscation + unused-resource stripping), and every
  CI build (`.github/actions/build-shop-apk/action.yml`) uses
  `--split-per-abi` so a device downloads only the native code for its
  own architecture instead of a universal APK carrying all of them.
- **Fewer, smaller image decodes**: `core/widgets/shop_logo.dart` uses
  `CachedNetworkImage` instead of `Image.network` for shop
  logos/branding, so a logo is downloaded and decoded once and reused
  from memory/disk everywhere it's shown (splash, single-shop home,
  shop profile) rather than re-fetched per screen. It also passes
  `memCacheWidth` so a large shopkeeper-uploaded image is decoded down
  to display size instead of held in memory at full resolution.
- **No more building the whole catalog up front**:
  `features/customer/shop_profile_screen.dart`'s product list was a
  plain `ListView` that eagerly built a `ProductTile` (each with its own
  `Consumer<CartController>` add-to-cart control) for every product in
  the shop at once. It's now a `CustomScrollView` with a
  `SliverList.builder`, so only tiles actually scrolled into view get
  built -- the difference is small for a 10-product shop and large for
  a 200-product one.
- **Fewer widget rebuilds on cart changes**:
  `features/customer/customer_shell_screen.dart` used
  `context.watch<CartController>()` at the top of `build()`, so every
  add-to-cart rebuilt the whole shell (bottom nav + the `IndexedStack`
  wrapper) just to update one badge number. Replaced with
  `Selector<CartController, int>` scoped to just the badge widget.

## Worth doing next

- **Pagination on admin/shopkeeper list screens** (all orders, all
  shops, sales history): these currently fetch everything in one call.
  Fine at demo scale, not at real scale -- add a `limit`/`offset` or
  cursor to the relevant backend endpoints and switch those screens to
  `ListView.builder` + "load more".
- **Const audit**: a handful of widgets across the shopkeeper/admin
  screens (built earlier than the customer-facing ones touched here)
  could drop a few more allocations with `const` constructors. Low risk,
  low individual impact -- best done with `flutter analyze`'s
  `prefer_const_constructors` lint turned on and fixed in bulk, which
  needs the Flutter SDK (not available in the environment used to make
  this pass).
- **Image compression on upload**: shop logos/banners are stored as raw
  URLs today (the shopkeeper pastes a link -- see `shop_setup_screen.dart`).
  If/when this becomes a real upload flow, compress and resize
  client-side before upload; a multi-megabyte photo as a 48dp app icon
  source is wasted bandwidth and wasted decode time both at build time
  (`flutter_launcher_icons` in CI) and at runtime.
- **`flutter build apk --release` startup**: consider deferred
  components / `--target-platform` splits further, and profiling actual
  cold-start time on a low-end device once real product/order volumes
  exist -- the changes above address the "obviously wasteful" cases
  visible from reading the code; a profiler run would find the rest.
