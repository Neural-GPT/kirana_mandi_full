import '../../core/errors/exceptions.dart';
import '../models/user_model.dart';
import '../remote/api_client.dart';
import '../repositories/auth_repository.dart';

/// Talks to the FastAPI backend (kirana_backend/) instead of the local
/// SQLite `users`/`otp_codes` tables. Wired in main.dart in place of
/// [DevAuthRepository]/[TextbeeAuthRepository] whenever
/// `EnvConfig.useRemoteApi` is true -- OTP sending itself still happens
/// server-side via the same textbee.dev integration, just from the
/// backend instead of the device.
class HttpAuthRepository implements AuthRepository {
  final ApiClient _client;

  HttpAuthRepository(this._client);

  @override
  Future<String?> sendOtp(String phone) async {
    final json = await _client.post('/auth/otp/send', body: {'phone': phone});
    // Populated only when the backend's textbee isn't configured -- a
    // fresh random code each time, NOT the fixed on-device "1234".
    return json['debug_otp'] as String?;
  }

  @override
  Future<UserModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? name,
  }) async {
    final json = await _client.post('/auth/otp/verify', body: {
      'phone': phone,
      'otp': otp,
      'role': role,
      if (name != null) 'name': name,
    });
    await _client.setToken(json['access_token'] as String);
    return _userFromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> loginEnvAdmin() async {
    // AdminLoginScreen calls [loginWithAdminCredentials] instead when
    // EnvConfig.useRemoteApi is true (see that screen), because the
    // backend needs the actual id/password to check against its own
    // ADMIN_ID/ADMIN_PASSWORD -- this method exists only to satisfy the
    // shared AuthRepository interface, and should never actually be
    // reached in a correctly wired app.
    throw AuthException(
      'Admin login needs id/password to be sent to the server -- '
      'this build is misconfigured.',
    );
  }

  /// Used by AdminLoginScreen when EnvConfig.useRemoteApi is true: sends
  /// the entered id/password straight to the backend rather than
  /// checking them on-device, since the backend is the real
  /// authorization boundary once one exists. Both sides must be
  /// configured with matching ADMIN_ID/ADMIN_PASSWORD values (see
  /// kirana_backend/README.md).
  Future<UserModel> loginWithAdminCredentials({
    required String adminId,
    required String password,
  }) async {
    final json = await _client.post('/auth/admin/login', body: {
      'admin_id': adminId,
      'password': password,
    });
    await _client.setToken(json['access_token'] as String);
    return _userFromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    // The backend infers identity from the bearer token (there is no
    // "look up any user by id" endpoint, for privacy), so this ignores
    // [id] and simply asks "who am I" -- which is exactly what
    // AuthController.restoreSession() needs. No token yet (fresh
    // install, or a token that failed to load) means no session.
    if (_client.authToken == null) return null;
    try {
      final json = await _client.get('/auth/me');
      return _userFromJson(json as Map<String, dynamic>);
    } on AuthException {
      // Token expired/invalid server-side -- treat as logged out.
      _client.clearToken();
      return null;
    } on UnauthorizedException {
      _client.clearToken();
      return null;
    }
  }

  @override
  Future<UserModel?> getUserByPhone(String phone) async {
    // Not exposed by the API (arbitrary phone lookup would be a privacy
    // hole), and nothing in the app calls this on the AuthRepository
    // interface directly -- see SqliteAuthRepository, where it's only
    // ever used internally.
    return null;
  }

  @override
  Future<List<UserModel>> getUsersByRole(String role) async {
    final json = await _client.get('/admin/users', query: {'role': role});
    return (json as List).map((u) => _userFromJson(u as Map<String, dynamic>)).toList();
  }

  UserModel _userFromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String?,
        role: json['role'] as String,
        createdAt: json['created_at'] as String,
      );
}