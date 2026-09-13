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
}
