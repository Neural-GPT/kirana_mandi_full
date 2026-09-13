import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../local/database_helper.dart';
import '../models/shop_model.dart';
import 'sync_queue_repository.dart';

abstract class ShopRepository {
  Future<List<ShopModel>> getShopsByRegion(String regionId,
      {bool approvedOnly = true});
  Future<List<ShopModel>> searchShopsByName(String query);
  Future<List<ShopModel>> getAllShops();
  Future<ShopModel?> getShopById(String id);
  Future<ShopModel?> getShopByOwnerId(String ownerUserId);
  Future<ShopModel> createShop(ShopModel shop);
  Future<void> updateShop(ShopModel shop, {required String requestingUserId});
  Future<void> setShopAvailability(String shopId, bool isAvailable,
      {required String requestingUserId});

  // Admin-only
  Future<List<ShopModel>> getShopsByStatus(String status);
  Future<void> setShopStatus(String shopId, String status);
  Future<Map<String, int>> getPlatformStats();
}

class SqliteShopRepository implements ShopRepository {
  final _uuid = const Uuid();
  final SyncQueueRepository _syncQueue;

  SqliteShopRepository({SyncQueueRepository? syncQueue})
      : _syncQueue = syncQueue ?? SyncQueueRepository();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<List<ShopModel>> getShopsByRegion(String regionId,
      {bool approvedOnly = true}) async {
    final db = await _db;
    final rows = await db.query(
      'shops',
      where: approvedOnly
          ? 'region_id = ? AND status = ? AND is_available = 1'
          : 'region_id = ?',
      whereArgs: approvedOnly
          ? [regionId, AppConstants.shopStatusApproved]
          : [regionId],
      orderBy: 'name ASC',
    );
    return rows.map(ShopModel.fromMap).toList();
  }

  @override
  Future<List<ShopModel>> searchShopsByName(String query) async {
    final db = await _db;
    final rows = await db.query(
      'shops',
      where: 'name LIKE ? AND status = ? AND is_available = 1',
      whereArgs: ['%$query%', AppConstants.shopStatusApproved],
      orderBy: 'name ASC',
    );
    return rows.map(ShopModel.fromMap).toList();
  }

  @override
  Future<List<ShopModel>> getAllShops() async {
    final db = await _db;
    final rows = await db.query('shops', orderBy: 'created_at DESC');
    return rows.map(ShopModel.fromMap).toList();
  }

  @override
  Future<ShopModel?> getShopById(String id) async {
    final db = await _db;
    final rows = await db.query('shops', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ShopModel.fromMap(rows.first);
  }

  @override
  Future<ShopModel?> getShopByOwnerId(String ownerUserId) async {
    final db = await _db;
    final rows = await db.query('shops',
        where: 'owner_user_id = ?', whereArgs: [ownerUserId]);
    if (rows.isEmpty) return null;
    return ShopModel.fromMap(rows.first);
  }

  @override
  Future<ShopModel> createShop(ShopModel shop) async {
    final db = await _db;
    final withId = ShopModel(
      id: shop.id.isEmpty ? _uuid.v4() : shop.id,
      ownerUserId: shop.ownerUserId,
      name: shop.name,
      ownerName: shop.ownerName,
      phone: shop.phone,
      altPhone: shop.altPhone,
      description: shop.description,
      categoryId: shop.categoryId,
      regionId: shop.regionId,
      latitude: shop.latitude,
      longitude: shop.longitude,
      formattedAddress: shop.formattedAddress,
      status: AppConstants.shopStatusPending, // every new shop needs approval
      isAvailable: true,
      homeDeliveryAvailable: shop.homeDeliveryAvailable,
      deliveryRadiusKm: shop.deliveryRadiusKm,
      deliveryFee: shop.deliveryFee,
      createdAt: DateTime.now().toIso8601String(),
    );
    await db.insert('shops', withId.toMap());
    await _syncQueue.enqueue(
        entityType: 'shop', entityId: withId.id, operation: 'create');
    return withId;
  }

  @override
  Future<void> updateShop(ShopModel shop,
      {required String requestingUserId}) async {
    final db = await _db;
    // Defensive ownership check on-device. The production API MUST
    // re-verify this server-side using the authenticated session --
    // client-supplied identifiers are never trusted as authorization
    // (PRD §39).
    if (shop.ownerUserId != requestingUserId) {
      throw UnauthorizedException('You do not own this shop.');
    }
    await db.update('shops', shop.toMap(), where: 'id = ?', whereArgs: [shop.id]);
    await _syncQueue.enqueue(
        entityType: 'shop', entityId: shop.id, operation: 'update');
  }

  @override
  Future<void> setShopAvailability(String shopId, bool isAvailable,
      {required String requestingUserId}) async {
    final shop = await getShopById(shopId);
    if (shop == null) throw NotFoundException('Shop not found.');
    if (shop.ownerUserId != requestingUserId) {
      throw UnauthorizedException('You do not own this shop.');
    }
    final db = await _db;
    await db.update('shops', {'is_available': isAvailable ? 1 : 0},
        where: 'id = ?', whereArgs: [shopId]);
  }

  @override
  Future<List<ShopModel>> getShopsByStatus(String status) async {
    final db = await _db;
    final rows = await db.query('shops',
        where: 'status = ?', whereArgs: [status], orderBy: 'created_at DESC');
    return rows.map(ShopModel.fromMap).toList();
  }

  @override
  Future<void> setShopStatus(String shopId, String status) async {
    final db = await _db;
    await db.update('shops', {'status': status},
        where: 'id = ?', whereArgs: [shopId]);
  }

  @override
  Future<Map<String, int>> getPlatformStats() async {
    final db = await _db;
    final totalShops =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM shops')) ?? 0;
    final pendingShops = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM shops WHERE status = ?',
            [AppConstants.shopStatusPending])) ??
        0;
    final approvedShops = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM shops WHERE status = ?',
            [AppConstants.shopStatusApproved])) ??
        0;
    final totalProducts =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
    final totalRegions = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM regions WHERE is_active = 1')) ??
        0;
    final totalCustomers = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM users WHERE role = ?',
            [AppConstants.roleCustomer])) ??
        0;

    return {
      'totalShops': totalShops,
      'pendingShops': pendingShops,
      'approvedShops': approvedShops,
      'totalProducts': totalProducts,
      'totalRegions': totalRegions,
      'totalCustomers': totalCustomers,
    };
  }
}
