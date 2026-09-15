import 'package:flutter/foundation.dart';
import '../../core/storage/session_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/http_auth_repository.dart';
import '../../data/repositories/auth_repository.dart';

enum SessionRestoreState { loading, restored, none }

/// Holds the current session and persists it via [SessionStorage] so the
/// user stays logged in across app restarts until they explicitly log
/// out. On app boot, call [restoreSession] once (see SplashScreen) before
/// deciding which screen to show.
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;
  // Only set when running against the FastAPI backend (see main.dart) --
  // logout() clears its in-memory token so a stale bearer token can't
  // linger into the next session on the same app instance.
  final ApiClient? _apiClient;

  AuthController(this._authRepository, {SessionStorage? sessionStorage, ApiClient? apiClient})
      : _sessionStorage = sessionStorage ?? SessionStorage(),
        _apiClient = apiClient;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  SessionRestoreState restoreState = SessionRestoreState.loading;

  /// Attempts to restore a previously logged-in session from disk. Safe to
  /// call once at app start; leaves [restoreState] as `restored` or `none`
  /// so the splash screen knows where to route.
  Future<void> restoreSession() async {
    try {
      final userId = await _sessionStorage.getUserId();
      if (userId == null) {
        restoreState = SessionRestoreState.none;
        notifyListeners();
        return;
      }
      final user = await _authRepository.getUserById(userId);
      if (user == null) {
        // Stale/deleted account -- clear it rather than looping forever.
        await _sessionStorage.clear();
        restoreState = SessionRestoreState.none;
      } else {
        _currentUser = user;
        restoreState = SessionRestoreState.restored;
      }
    } catch (_) {
      // If restore fails for any reason (corrupt prefs, db not ready),
      // fail safe to the login flow rather than blocking app startup.
      restoreState = SessionRestoreState.none;
    }
    notifyListeners();
  }

  Future<String?> sendOtp(String phone) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await _authRepository.sendOtp(phone);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? name,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final user = await _authRepository.verifyOtp(
        phone: phone,
        otp: otp,
        role: role,
        name: name,
      );
      _currentUser = user;
      await _sessionStorage.saveUserId(user.id);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Logs in the single configured admin account. Against the local
  /// SQLite build, AdminLoginScreen has already checked [adminId]/
  /// [password] against its own EnvConfig before calling this, and this
  /// just establishes the session. Against the FastAPI backend
  /// (EnvConfig.useRemoteApi), the credentials are sent to the server
  /// instead -- the backend is the real authorization boundary there,
  /// so it does the actual check against its own ADMIN_ID/ADMIN_PASSWORD.
  Future<bool> loginAdmin({required String adminId, required String password}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final UserModel user;
      final authRepository = _authRepository;
      if (authRepository is HttpAuthRepository) {
        user = await authRepository.loginWithAdminCredentials(
          adminId: adminId,
          password: password,
        );
      } else {
        user = await authRepository.loginEnvAdmin();
      }
      _currentUser = user;
      await _sessionStorage.saveUserId(user.id);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    await _sessionStorage.clear();
    _apiClient?.clearToken();
    notifyListeners();
  }
}