import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/service_model.dart';

abstract class ServiceRepository {
  Future<List<ServiceModel>> getAllServices({bool activeOnly = true});
  Future<void> create(ServiceModel service);
  Future<void> update(ServiceModel service);
  Future<void> setActive(String id, bool isActive);

  // Shop <-> service links
  Future<List<String>> getServiceIdsForShop(String shopId);
  Future<void> setShopServices(String shopId, List<String> serviceIds);
}

class SqliteServiceRepository implements ServiceRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<List<ServiceModel>> getAllServices({bool activeOnly = true}) async {
    final db = await _db;
    final rows = await db.query(
      'services',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(ServiceModel.fromMap).toList();
  }

  @override
  Future<void> create(ServiceModel service) async {
    final db = await _db;
    await db.insert('services', service.toMap());
  }

  @override
  Future<void> update(ServiceModel service) async {
    final db = await _db;
    await db.update('services', service.toMap(),
        where: 'id = ?', whereArgs: [service.id]);
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    final db = await _db;
    await db.update('services', {'is_active': isActive ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<String>> getServiceIdsForShop(String shopId) async {
    final db = await _db;
    final rows = await db.query('shop_services',
        where: 'shop_id = ?', whereArgs: [shopId]);
    return rows.map((r) => r['service_id'] as String).toList();
  }

  @override
  Future<void> setShopServices(String shopId, List<String> serviceIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('shop_services', where: 'shop_id = ?', whereArgs: [shopId]);
      for (final serviceId in serviceIds) {
        await txn.insert('shop_services', {
          'shop_id': shopId,
          'service_id': serviceId,
        });
      }
    });
  }
}
