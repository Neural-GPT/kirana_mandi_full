import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/connectivity_service.dart';
import '../local/database_helper.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  /// Sends (or in dev, simulates) an OTP to [phone].
  Future<String?> sendOtp(String phone);

  /// Verifies the OTP for [phone].
  ///
  /// For [AppConstants.roleCustomer] / [AppConstants.roleShopkeeper]: if no
  /// user exists yet for this phone, one is created with that role
  /// (self-service signup).
  ///
  /// For [AppConstants.roleAdmin]: admin accounts are never auto-created
  /// from the login screen. The phone must already exist in the users
  /// table with role admin/super_admin -- added ahead of time (the seeded
  /// super admin) or later via the super admin's "Manage Admins" screen.
  /// Otherwise this throws [AuthException].
  ///
  /// [name] is only used for customers/shopkeepers on first-time signup
  /// (a brand new user row is created with it). If the user already
  /// exists and [name] is non-null, their stored name is refreshed --
  /// this lets a customer correct a typo'd name next time they log in.
  Future<UserModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? name,
  });

  Future<UserModel?> getUserByPhone(String phone);
  Future<UserModel?> getUserById(String id);

  /// All users with the given role, newest first -- used by the admin
  /// dashboard's "Customers" detail view.
  Future<List<UserModel>> getUsersByRole(String role);

  /// Logs in (creating on first use) the single env-configured super
  /// admin account. The id/password check itself happens in
  /// [AdminLoginScreen] against [EnvConfig] -- by the time this is
  /// called, the caller has already confirmed the credentials match.
  /// This just gives that admin a real [UserModel] row/session so the
  /// rest of the app (Manage Admins, ownership checks, etc.) works the
  /// same way it does for any other admin.
  Future<UserModel> loginEnvAdmin();
}

/// Shared verify/lookup/create logic. Subclasses only need to implement
/// *how* an OTP is delivered and checked (fixed dev code vs. a real SMS
/// sent through textbee.dev) -- the security-relevant "who's allowed to
/// become an admin" logic lives here once, not duplicated per subclass.
abstract class BaseAuthRepository implements AuthRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @protected
  Future<String?> deliverOtp(String phone);

  @protected
  Future<bool> checkCode(String phone, String submittedCode);

  @override
  Future<String?> sendOtp(String phone) => deliverOtp(phone);

  @override
  Future<UserModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? name,
  }) async {
    final valid = await checkCode(phone, otp);
    if (!valid) {
      throw AuthException('Incorrect or expired OTP. Please try again.');
    }

    if (role == AppConstants.roleAdmin) {
      final existing = await getUserByPhone(phone);
      if (existing == null || !AppConstants.isAdminRole(existing.role)) {
        throw AuthException(
          'This phone number is not registered as an admin. '
          'Ask an existing admin to add you from Manage Admins, or '
          'contact ${AppConstants.companyName} (${AppConstants.companyPhone}).',
        );
      }
      return existing;
    }

    final existing = await getUserByPhone(phone);
    if (existing != null) {
      // Let a returning customer/shopkeeper correct their stored name
      // without creating a duplicate account.
      final trimmedName = name?.trim();
      if (trimmedName != null &&
          trimmedName.isNotEmpty &&
          trimmedName != existing.name) {
        final updated = existing.copyWith(name: trimmedName);
        final db = await _db;
        await db.update('users', updated.toMap(),
            where: 'id = ?', whereArgs: [existing.id]);
        return updated;
      }
      return existing;
    }

    final user = UserModel(
      id: _uuid.v4(),
      phone: phone,
      name: name?.trim().isEmpty == true ? null : name?.trim(),
      role: role,
      createdAt: DateTime.now().toIso8601String(),
    );
    final db = await _db;
    await db.insert('users', user.toMap());
    return user;
  }

  /// Synthetic phone used only to key the single env-configured admin's
  /// row in the local `users` table. Not a real phone number -- this
  /// admin never goes through the OTP flow, so it never needs to be.
  static const _envAdminPhone = 'env-admin';

  @override
  Future<UserModel> loginEnvAdmin() async {
    final existing = await getUserByPhone(_envAdminPhone);
    if (existing != null) return existing;

    final user = UserModel(
      id: _uuid.v4(),
      phone: _envAdminPhone,
      name: 'Admin',
      role: AppConstants.roleSuperAdmin,
      createdAt: DateTime.now().toIso8601String(),
    );
    final db = await _db;
    await db.insert('users', user.toMap());
    return user;
  }

  @override
  Future<UserModel?> getUserByPhone(String phone) async {
    final db = await _db;
    final rows = await db.query('users', where: 'phone = ?', whereArgs: [phone]);
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final db = await _db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  @override
  Future<List<UserModel>> getUsersByRole(String role) async {
    final db = await _db;
    final rows = await db.query('users',
        where: 'role = ?', whereArgs: [role], orderBy: 'created_at DESC');
    return rows.map(UserModel.fromMap).toList();
  }
}

/// Development implementation. OTP "verification" is a fixed local code
/// (AppConstants.devOtpCode) so the flow is testable without any SMS
/// gateway configured. This is the default (see main.dart) until a
/// textbee.dev API key is supplied.
class DevAuthRepository extends BaseAuthRepository {
  @override
  Future<String?> deliverOtp(String phone) async {
    // Nothing is actually sent -- but the OTP screen only shows the
    // "here's your code" box when it's handed a non-null debug code
    // (see OtpScreen.debugOtp), so the fixed dev code has to be
    // returned here, not just documented in a comment, or dev-mode
    // login is untestable without reading the source. Kept async with
    // a short delay so the UI's loading state behaves the same as the
    // real network-backed implementation.
    await Future.delayed(const Duration(milliseconds: 400));
    return AppConstants.devOtpCode;
  }

  @override
  Future<bool> checkCode(String phone, String submittedCode) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return submittedCode == AppConstants.devOtpCode;
  }
}

/// Production-style implementation: generates a real one-time code,
/// stores it locally with an expiry, and sends it as an SMS via the
/// textbee.dev gateway (an Android phone acting as an SMS sender --
/// see https://textbee.dev/docs). Fill in [apiKey] to use this; it's
/// wired up but disabled by default via [EnvConfig.useTextbeeOtp] so
/// the app doesn't try to hit a real API with a placeholder key.
///
/// Note this app has no backend yet (SQLite is local per-device), so the
/// OTP is generated and checked on-device rather than server-side. Once
/// the Aiven Postgres-backed API exists, move OTP generation/validation
/// there instead -- a client-side-only OTP is fine for an internal MVP,
/// not for a hardened production login.
class TextbeeAuthRepository extends BaseAuthRepository {
  final String apiKey;
  final String deviceId;
  final ConnectivityService? connectivityService;
  final http.Client _client;
  final Random _random = Random.secure();

  TextbeeAuthRepository({
    required this.apiKey,
    required this.deviceId,
    this.connectivityService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // textbee.dev sends through a specific registered Android device, so
  // the device id is part of the path, not just a header/body field --
  // see https://textbee.dev/docs.
  String get _sendUrl =>
      'https://api.textbee.dev/api/v1/gateway/devices/$deviceId/send-sms';

  String _generateCode() => (1000 + _random.nextInt(9000)).toString();

  @override
  Future<String?> deliverOtp(String phone) async {
    if (connectivityService != null && !connectivityService!.isOnline) {
      throw OfflineException(
          "You're offline. Connect to the internet to receive an OTP.");
    }

    final code = _generateCode();
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'otp_codes',
      {
        'phone': phone,
        'code': code,
        'expires_at':
            DateTime.now().add(AppConstants.otpValidity).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      final response = await _client
          .post(
            Uri.parse(_sendUrl),
            headers: {
              'x-api-key': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'recipients': ['+91$phone'],
              'message':
                  'Your ${AppConstants.appName} verification code is $code. Valid for 5 minutes.',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NetworkException(
            'Could not send OTP right now (server returned ${response.statusCode}). Please try again.');
      }
    } on TimeoutException {
      throw NetworkException('The request timed out. Please try again.');
    } on http.ClientException {
      throw NetworkException(
          'Could not reach the SMS service. Please check your connection and try again.');
    }
  }

  @override
  Future<bool> checkCode(String phone, String submittedCode) async {
    final db = await DatabaseHelper.instance.database;
    final rows =
        await db.query('otp_codes', where: 'phone = ?', whereArgs: [phone]);
    if (rows.isEmpty) return false;

    final row = rows.first;
    final expiresAt = DateTime.parse(row['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) {
      await db.delete('otp_codes', where: 'phone = ?', whereArgs: [phone]);
      return false;
    }

    final matches = row['code'] as String == submittedCode;
    if (matches) {
      // Single-use: remove once consumed successfully.
      await db.delete('otp_codes', where: 'phone = ?', whereArgs: [phone]);
    }
    return matches;
  }
}
