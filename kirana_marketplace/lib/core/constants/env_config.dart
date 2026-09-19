/// Build-time configuration read from `--dart-define` values so secrets
/// never live in source control.
///
/// Example (run/build):
/// ```
/// flutter run \
///   --dart-define=ADMIN_ID=owner \
///   --dart-define=ADMIN_PASSWORD=changeMe123 \
///   --dart-define=TEXTBEE_API_KEY=xxxxx \
///   --dart-define=TEXTBEE_DEVICE_ID=xxxxx \
///   --dart-define=USE_TEXTBEE_OTP=true
/// ```
///
/// Or put the same `--dart-define=KEY=value` lines (one per line, no
/// quotes) into a `dart_defines.txt` / your IDE's "Additional run args"
/// so you don't have to retype them every run. Never commit real values
/// -- keep them in an untracked file or your CI's secret store.
class EnvConfig {
  EnvConfig._();

  /// Admin login id, set by whoever deploys the app. Defaults to empty,
  /// which means the admin login screen will refuse ALL id/password
  /// combinations until this is configured -- fail closed, not open.
  static const String adminId = String.fromEnvironment('ADMIN_ID');

  static const String adminPassword =
      String.fromEnvironment('ADMIN_PASSWORD');

  static bool get isAdminLoginConfigured =>
      adminId.isNotEmpty && adminPassword.isNotEmpty;

  /// textbee.dev credentials. Get these from your textbee.dev dashboard
  /// after installing the textbee app on an Android phone and registering
  /// it as a device (see README "OTP delivery").
  static const String textbeeApiKey = String.fromEnvironment('TEXTBEE_API_KEY');
  static const String textbeeDeviceId =
      String.fromEnvironment('TEXTBEE_DEVICE_ID');

  /// Explicit override. If not passed, real SMS sending is automatically
  /// enabled once both textbee values above are present -- so you don't
  /// have to flip two separate switches to go live.
  static const bool _useTextbeeOtpOverride =
      bool.fromEnvironment('USE_TEXTBEE_OTP', defaultValue: false);

  static bool get useTextbeeOtp =>
      _useTextbeeOtpOverride ||
      (textbeeApiKey.isNotEmpty && textbeeDeviceId.isNotEmpty);

  /// Base URL of the FastAPI backend (see kirana_backend/), e.g.
  /// `https://kirana-mandi-api.onrender.com`. When this is set, the app
  /// talks to that backend via the `Http*Repository` classes; when it's
  /// left blank, the app falls back to the on-device SQLite
  /// `Sqlite*Repository` classes (offline-only / single-device demo
  /// mode) -- see main.dart. No trailing slash.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get useRemoteApi => apiBaseUrl.isNotEmpty;

  // --- White-label build configuration ---
  //
  // These three flags are how a single core Flutter codebase becomes a
  // shop-specific APK/web build for the "Build Automation Config"
  // distribution path (see ShopkeeperPortal > App Deployment):
  //
  //   flutter build apk \
  //     --dart-define=API_BASE_URL=https://kirana-mandi-api.onrender.com \
  //     --dart-define=SHOP_ID=b6b8b3f0-... \
  //     --dart-define=APP_NAME="Sharma General Store" \
  //     --dart-define=PRIMARY_COLOR=2E7D32
  //
  /// The tenant this build is permanently locked to. When non-empty, the
  /// customer experience skips multi-shop/region discovery entirely and
  /// shows only this one shop's catalog and branding (see
  /// ShopThemeController and CustomerHomeScreen) -- this is the
  /// "Build Automation" white-label path. Leave blank for the normal
  /// multi-shop marketplace build, or for the "Dynamic / On-the-Fly"
  /// build where the shop is chosen at runtime via a Shop Code instead
  /// (see ShopEntryScreen).
  static const String shopId = String.fromEnvironment('SHOP_ID');

  static bool get isWhiteLabelBuild => shopId.isNotEmpty;

  /// Overrides [AppConstants.appName] for a shop-specific build. Falls
  /// back to the platform-level app name when not set (e.g. multi-shop
  /// builds, or a white-label build that just didn't bother customizing
  /// this).
  static const String appNameOverride = String.fromEnvironment('APP_NAME');

  /// Hex color (with or without a leading '#', e.g. "2E7D32" or
  /// "#2E7D32") used as the seed for this build's theme. Falls back to
  /// the shop's own `primary_color` (fetched from `/shops/{id}/branding`
  /// at runtime) when unset, and to the default app palette if neither
  /// is present -- see ShopThemeController.
  static const String primaryColorOverride = String.fromEnvironment('PRIMARY_COLOR');
  static const String secondaryColorOverride = String.fromEnvironment('SECONDARY_COLOR');
}
