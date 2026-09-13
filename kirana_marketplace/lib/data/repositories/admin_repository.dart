import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../local/database_helper.dart';
import '../models/user_model.dart';

abstract class AdminRepository {
  Future<List<UserModel>> getAllAdmins();

  /// Adds a new admin/super-admin by phone number. Fails if that phone is
  /// already registered under a different role (a shopkeeper or customer
  /// number can't silently become an admin). [addedByUserId] is recorded
  /// defensively -- callers must already have verified the requester is a
  /// super admin before calling this.
  Future<UserModel> addAdmin({
    required String phone,
    required String name,
    required String role, // admin | super_admin
    required String addedByUserId,
  });

  Future<void> removeAdmin(String userId, {required String requestedByRole});
}

class SqliteAdminRepository implements AdminRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<List<UserModel>> getAllAdmins() async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'role = ? OR role = ?',
      whereArgs: [AppConstants.roleAdmin, AppConstants.roleSuperAdmin],
      orderBy: 'created_at ASC',
    );
    return rows.map(UserModel.fromMap).toList();
  }

  @override
  Future<UserModel> addAdmin({
    required String phone,
    required String name,
    required String role,
    required String addedByUserId,
  }) async {
    if (role != AppConstants.roleAdmin && role != AppConstants.roleSuperAdmin) {
      throw ValidationException('Role must be admin or super_admin.');
    }
    final db = await _db;
    final existingRows =
        await db.query('users', where: 'phone = ?', whereArgs: [phone]);

    if (existingRows.isNotEmpty) {
      final existing = UserModel.fromMap(existingRows.first);
      if (AppConstants.isAdminRole(existing.role)) {
        throw ValidationException('This phone number is already an admin.');
      }
      throw ValidationException(
          'This phone number is already registered as a ${existing.role}.');
    }

    final user = UserModel(
      id: _uuid.v4(),
      phone: phone,
      name: name,
      role: role,
      createdAt: DateTime.now().toIso8601String(),
    );
    await db.insert('users', user.toMap());
    return user;
  }

  @override
  Future<void> removeAdmin(String userId,
      {required String requestedByRole}) async {
    if (requestedByRole != AppConstants.roleSuperAdmin) {
      throw UnauthorizedException('Only a super admin can remove admins.');
    }
    final db = await _db;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }
}
