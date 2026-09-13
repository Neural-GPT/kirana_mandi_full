import '../models/user_model.dart';
import '../remote/api_client.dart';
import '../repositories/admin_repository.dart';

class HttpAdminRepository implements AdminRepository {
  final ApiClient _client;
  HttpAdminRepository(this._client);

  UserModel _fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String?,
        role: json['role'] as String,
        createdAt: json['created_at'] as String,
      );

  @override
  Future<List<UserModel>> getAllAdmins() async {
    final json = await _client.get('/admin/admins');
    return (json as List).map((u) => _fromJson(u as Map<String, dynamic>)).toList();
  }

  @override
  Future<UserModel> addAdmin({
    required String phone,
    required String name,
    required String role,
    required String addedByUserId,
  }) async {
    // The backend independently enforces both the role check and the
    // "phone already used under a different role" conflict check
    // server-side (the real authorization boundary); [addedByUserId] is
    // accepted here only for interface parity with the on-device
    // implementation, which records it defensively.
    final json = await _client.post('/admin/admins', body: {
      'phone': phone,
      'name': name,
      'role': role,
    });
    return _fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> removeAdmin(String userId, {required String requestedByRole}) async {
    // The backend enforces the super_admin-only check itself (via the
    // bearer token), throwing the same UnauthorizedException shape via
    // ApiClient's 403 mapping if it doesn't hold.
    await _client.delete('/admin/admins/$userId');
  }
}
