import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';

/// Appends an entry every time a repository makes a local write. Once the
/// app talks to the Aiven Postgres-backed API instead of local SQLite,
/// a background worker can drain this table (oldest first, `synced = 0`)
/// and push each change up, then mark it synced. Until then it's inert --
/// pure bookkeeping that costs one extra insert per write and makes the
/// offline-first migration path concrete rather than aspirational.
class SyncQueueRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation, // 'create' | 'update' | 'delete'
    Map<String, Object?>? payload,
  }) async {
    final db = await _db;
    await db.insert('sync_queue', {
      'id': _uuid.v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload_json': payload == null ? null : jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<int> pendingCount() async {
    final db = await _db;
    final rows = await db
        .rawQuery('SELECT COUNT(*) as c FROM sync_queue WHERE synced = 0');
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
