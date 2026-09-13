import 'package:shared_preferences/shared_preferences.dart';

/// Persists the logged-in user's id (and, when talking to the FastAPI
/// backend, their bearer token) so the app can restore a session on cold
/// start without asking for OTP again every time -- "keep the person
/// logged in until they log out."
class SessionStorage {
  static const _kUserId = 'session_user_id';
  static const _kAuthToken = 'session_auth_token';

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserId);
  }

  /// Only meaningful when running against the FastAPI backend
  /// (EnvConfig.useRemoteApi) -- ApiClient persists/restores this so the
  /// bearer token survives an app restart without the person having to
  /// verify OTP again.
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthToken, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAuthToken);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kAuthToken);
  }
}
