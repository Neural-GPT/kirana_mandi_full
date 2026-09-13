import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../models/call_log_model.dart';

abstract class CallLogRepository {
  /// Records a call. [callerLabel] is optional context (e.g. a name if the
  /// customer volunteered one); customers aren't authenticated in this
  /// app, so most entries will just be a bare timestamp.
  Future<void> logCall({required String shopId, String? callerLabel});

  Future<List<CallLogModel>> getCallsForShop(String shopId, {int limit = 100});
  Future<int> getCallCountSince(String shopId, DateTime since);
}

class SqliteCallLogRepository implements CallLogRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<void> logCall({required String shopId, String? callerLabel}) async {
    final db = await _db;
    await db.insert('call_logs', {
      'id': _uuid.v4(),
      'shop_id': shopId,
      'caller_label': callerLabel,
      'called_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<CallLogModel>> getCallsForShop(String shopId,
      {int limit = 100}) async {
    final db = await _db;
    final rows = await db.query(
      'call_logs',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'called_at DESC',
      limit: limit,
    );
    return rows.map(CallLogModel.fromMap).toList();
  }

  @override
  Future<int> getCallCountSince(String shopId, DateTime since) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM call_logs WHERE shop_id = ? AND called_at >= ?',
      [shopId, since.toIso8601String()],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
