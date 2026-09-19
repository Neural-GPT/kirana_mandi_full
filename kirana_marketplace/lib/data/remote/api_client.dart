import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/exceptions.dart';
import '../../core/storage/session_storage.dart';

/// Thin wrapper around `http` for talking to the FastAPI backend
/// (kirana_backend/): builds URIs against [baseUrl], attaches the bearer
/// token, encodes/decodes JSON, and maps HTTP error responses onto the
/// same exception types the rest of the app already expects from the
/// on-device repositories (see core/errors/exceptions.dart) so screens
/// using `runGuarded()` don't need to know or care whether a repository
/// is backed by SQLite or this API.
///
/// One instance is created in main.dart and shared by every
/// `Http*Repository`, so logging in once (which calls [setToken]) makes
/// every other repository authenticated immediately.
class ApiClient {
  final String baseUrl;
  final http.Client _client;
  final SessionStorage _sessionStorage;
  String? _token;

  // Set once ShopThemeController locks this install to one shop (build-time
  // via EnvConfig.shopId, or at runtime via the Dynamic/Shop-Code flow --
  // see ShopEntryScreen). Sent as `X-Shop-ID` on every request so the
  // backend's tenant-isolation guard (verify_tenant_scope) can reject any
  // request that somehow targets a different shop_id. Optional: a
  // multi-shop build never sets this and nothing changes for it.
  String? _shopId;

  static const _timeout = Duration(seconds: 15);

  ApiClient({
    required this.baseUrl,
    http.Client? client,
    SessionStorage? sessionStorage,
  })  : _client = client ?? http.Client(),
        _sessionStorage = sessionStorage ?? SessionStorage();

  String? get authToken => _token;

  /// Locks every subsequent request to carry `X-Shop-ID: $shopId`. Pass
  /// null to clear the lock (e.g. switching shops in Dynamic mode).
  void setTenantShopId(String? shopId) {
    _shopId = (shopId == null || shopId.isEmpty) ? null : shopId;
  }

  /// Loads a previously-persisted token into memory. Call once at app
  /// startup (before runApp) so a restored session's very first request
  /// -- e.g. SplashScreen's GET /auth/me -- already carries it.
  Future<void> restoreToken() async {
    _token = await _sessionStorage.getToken();
  }

  /// Called by Http*AuthRepository right after a successful login.
  Future<void> setToken(String token) async {
    _token = token;
    await _sessionStorage.saveToken(token);
  }

  /// Called on logout. Only clears the in-memory/persisted token; the
  /// user id half of SessionStorage is AuthController's responsibility.
  void clearToken() {
    _token = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (_shopId != null) 'X-Shop-ID': _shopId!,
      };

  Uri _uri(String path, Map<String, dynamic>? query) {
    Map<String, String>? stringQuery;
    if (query != null) {
      stringQuery = {};
      query.forEach((key, value) {
        if (value != null) stringQuery![key] = value.toString();
      });
    }
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: (stringQuery == null || stringQuery.isEmpty) ? null : stringQuery,
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    final encodedBody = body == null ? null : jsonEncode(body);

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: _headers).timeout(_timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: _headers, body: encodedBody)
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: _headers, body: encodedBody)
              .timeout(_timeout);
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: _headers, body: encodedBody)
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: _headers).timeout(_timeout);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      throw NetworkException('The request timed out. Check your connection and try again.');
    } on SocketException {
      throw NetworkException('No internet connection. Check your network and try again.');
    } on http.ClientException {
      throw NetworkException('Could not reach the server. Please try again.');
    }

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final status = response.statusCode;

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (status >= 200 && status < 300) return decoded;

    String message = 'Something went wrong. Please try again.';
    if (decoded is Map && decoded['detail'] != null) {
      message = decoded['detail'].toString();
    }

    switch (status) {
      case 400:
      case 409:
      case 422:
        throw ValidationException(message);
      case 401:
        throw AuthException(message);
      case 403:
        throw UnauthorizedException(message);
      case 404:
        throw NotFoundException(message);
      default:
        throw NetworkException(message);
    }
  }
}
