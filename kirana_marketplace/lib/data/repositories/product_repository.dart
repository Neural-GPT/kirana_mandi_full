import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/exceptions.dart';
import '../local/database_helper.dart';
import '../models/product_model.dart';
import '../models/shop_model.dart';
import 'shop_repository.dart';
import 'sync_queue_repository.dart';

/// A search hit that carries along the parent shop, since customers
/// searching for a product need to know which shop sells it (PRD §4.1).
class ProductSearchResult {
  final ProductModel product;
  final ShopModel shop;
  ProductSearchResult({required this.product, required this.shop});
}

abstract class ProductRepository {
  Future<List<ProductModel>> getProductsByShop(String shopId,
      {bool availableOnly = false});
  Future<ProductModel?> getProductById(String id);
  Future<ProductModel> createProduct(ProductModel product,
      {required String requestingUserId});
  Future<void> updateProduct(ProductModel product,
      {required String requestingUserId});
  Future<void> deleteProduct(String productId,
      {required String requestingUserId});
  Future<void> setProductAvailability(String productId, bool isAvailable,
      {required String requestingUserId});
  Future<List<ProductSearchResult>> searchProductsByName(String query,
      {String? regionId});

  /// Every product across every shop (any status), newest shop first --
  /// used by the admin dashboard's "Total Products" detail view. Capped
  /// via [limit] since a growing marketplace could have thousands.
  Future<List<ProductSearchResult>> getAllProductsAcrossShops({int limit = 200});
}

class SqliteProductRepository implements ProductRepository {
  final _uuid = const Uuid();
  final ShopRepository shopRepository;
  final SyncQueueRepository _syncQueue;

  SqliteProductRepository({
    required this.shopRepository,
    SyncQueueRepository? syncQueue,
  }) : _syncQueue = syncQueue ?? SyncQueueRepository();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> _assertOwnsShop(String shopId, String requestingUserId) async {
    final shop = await shopRepository.getShopById(shopId);
    if (shop == null) throw NotFoundException('Shop not found.');
    if (shop.ownerUserId != requestingUserId) {
      throw UnauthorizedException('You do not manage this shop.');
    }
  }

  @override
  Future<List<ProductModel>> getProductsByShop(String shopId,
      {bool availableOnly = false}) async {
    final db = await _db;
    final rows = await db.query(
      'products',
      where: availableOnly ? 'shop_id = ? AND is_available = 1' : 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'name ASC',
    );
    return rows.map(ProductModel.fromMap).toList();
  }

  @override
  Future<ProductModel?> getProductById(String id) async {
    final db = await _db;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ProductModel.fromMap(rows.first);
  }

  @override
  Future<ProductModel> createProduct(ProductModel product,
      {required String requestingUserId}) async {
    await _assertOwnsShop(product.shopId, requestingUserId);
    final db = await _db;
    final toInsert = ProductModel(
      id: product.id.isEmpty ? _uuid.v4() : product.id,
      shopId: product.shopId,
      name: product.name,
      categoryId: product.categoryId,
      price: product.price,
      unit: product.unit,
      iconId: product.iconId,
      isAvailable: product.isAvailable,
      description: product.description,
    );
    await db.insert('products', toInsert.toMap());
    await _syncQueue.enqueue(
        entityType: 'product', entityId: toInsert.id, operation: 'create');
    return toInsert;
  }

  @override
  Future<void> updateProduct(ProductModel product,
      {required String requestingUserId}) async {
    await _assertOwnsShop(product.shopId, requestingUserId);
    final db = await _db;
    await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
    await _syncQueue.enqueue(
        entityType: 'product', entityId: product.id, operation: 'update');
  }

  @override
  Future<void> deleteProduct(String productId,
      {required String requestingUserId}) async {
    final product = await getProductById(productId);
    if (product == null) throw NotFoundException('Product not found.');
    await _assertOwnsShop(product.shopId, requestingUserId);
    final db = await _db;
    await db.delete('products', where: 'id = ?', whereArgs: [productId]);
    await _syncQueue.enqueue(
        entityType: 'product', entityId: productId, operation: 'delete');
  }

  @override
  Future<void> setProductAvailability(String productId, bool isAvailable,
      {required String requestingUserId}) async {
    final product = await getProductById(productId);
    if (product == null) throw NotFoundException('Product not found.');
    await _assertOwnsShop(product.shopId, requestingUserId);
    final db = await _db;
    await db.update('products', {'is_available': isAvailable ? 1 : 0},
        where: 'id = ?', whereArgs: [productId]);
  }

  @override
  Future<List<ProductSearchResult>> searchProductsByName(String query,
      {String? regionId}) async {
    final db = await _db;
    final sql = StringBuffer('''
      SELECT
        products.id            AS p_id,
        products.shop_id       AS p_shop_id,
        products.name          AS p_name,
        products.category_id   AS p_category_id,
        products.price         AS p_price,
        products.unit          AS p_unit,
        products.icon_id       AS p_icon_id,
        products.is_available  AS p_is_available,
        products.description   AS p_description,
        shops.id                AS s_id,
        shops.owner_user_id     AS s_owner_user_id,
        shops.name              AS s_name,
        shops.owner_name        AS s_owner_name,
        shops.phone             AS s_phone,
        shops.alt_phone         AS s_alt_phone,
        shops.description       AS s_description,
        shops.category_id       AS s_category_id,
        shops.region_id         AS s_region_id,
        shops.latitude          AS s_latitude,
        shops.longitude         AS s_longitude,
        shops.formatted_address AS s_formatted_address,
        shops.status            AS s_status,
        shops.is_available      AS s_is_available,
        shops.home_delivery     AS s_home_delivery,
        shops.delivery_radius_km AS s_delivery_radius_km,
        shops.delivery_fee      AS s_delivery_fee,
        shops.created_at        AS s_created_at
      FROM products
      INNER JOIN shops ON products.shop_id = shops.id
      WHERE products.name LIKE ?
        AND products.is_available = 1
        AND shops.status = 'approved'
        AND shops.is_available = 1
    ''');
    final args = <Object?>['%$query%'];
    if (regionId != null) {
      sql.write(' AND shops.region_id = ?');
      args.add(regionId);
    }
    sql.write(' ORDER BY products.name ASC');

    final rows = await db.rawQuery(sql.toString(), args);
    return rows.map((row) {
      final product = ProductModel.fromMap({
        'id': row['p_id'],
        'shop_id': row['p_shop_id'],
        'name': row['p_name'],
        'category_id': row['p_category_id'],
        'price': row['p_price'],
        'unit': row['p_unit'],
        'icon_id': row['p_icon_id'],
        'is_available': row['p_is_available'],
        'description': row['p_description'],
      });
      final shop = ShopModel.fromMap({
        'id': row['s_id'],
        'owner_user_id': row['s_owner_user_id'],
        'name': row['s_name'],
        'owner_name': row['s_owner_name'],
        'phone': row['s_phone'],
        'alt_phone': row['s_alt_phone'],
        'description': row['s_description'],
        'category_id': row['s_category_id'],
        'region_id': row['s_region_id'],
        'latitude': row['s_latitude'],
        'longitude': row['s_longitude'],
        'formatted_address': row['s_formatted_address'],
        'status': row['s_status'],
        'is_available': row['s_is_available'],
        'home_delivery': row['s_home_delivery'],
        'delivery_radius_km': row['s_delivery_radius_km'],
        'delivery_fee': row['s_delivery_fee'],
        'created_at': row['s_created_at'],
      });
      return ProductSearchResult(product: product, shop: shop);
    }).toList();
  }

  @override
  Future<List<ProductSearchResult>> getAllProductsAcrossShops(
      {int limit = 200}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        products.id            AS p_id,
        products.shop_id       AS p_shop_id,
        products.name          AS p_name,
        products.category_id   AS p_category_id,
        products.price         AS p_price,
        products.unit          AS p_unit,
        products.icon_id       AS p_icon_id,
        products.is_available  AS p_is_available,
        products.description   AS p_description,
        shops.id                AS s_id,
        shops.owner_user_id     AS s_owner_user_id,
        shops.name              AS s_name,
        shops.owner_name        AS s_owner_name,
        shops.phone             AS s_phone,
        shops.alt_phone         AS s_alt_phone,
        shops.description       AS s_description,
        shops.category_id       AS s_category_id,
        shops.region_id         AS s_region_id,
        shops.latitude          AS s_latitude,
        shops.longitude         AS s_longitude,
        shops.formatted_address AS s_formatted_address,
        shops.status            AS s_status,
        shops.is_available      AS s_is_available,
        shops.home_delivery     AS s_home_delivery,
        shops.delivery_radius_km AS s_delivery_radius_km,
        shops.delivery_fee      AS s_delivery_fee,
        shops.created_at        AS s_created_at
      FROM products
      INNER JOIN shops ON products.shop_id = shops.id
      ORDER BY shops.name ASC, products.name ASC
      LIMIT ?
    ''', [limit]);

    return rows.map((row) {
      final product = ProductModel.fromMap({
        'id': row['p_id'],
        'shop_id': row['p_shop_id'],
        'name': row['p_name'],
        'category_id': row['p_category_id'],
        'price': row['p_price'],
        'unit': row['p_unit'],
        'icon_id': row['p_icon_id'],
        'is_available': row['p_is_available'],
        'description': row['p_description'],
      });
      final shop = ShopModel.fromMap({
        'id': row['s_id'],
        'owner_user_id': row['s_owner_user_id'],
        'name': row['s_name'],
        'owner_name': row['s_owner_name'],
        'phone': row['s_phone'],
        'alt_phone': row['s_alt_phone'],
        'description': row['s_description'],
        'category_id': row['s_category_id'],
        'region_id': row['s_region_id'],
        'latitude': row['s_latitude'],
        'longitude': row['s_longitude'],
        'formatted_address': row['s_formatted_address'],
        'status': row['s_status'],
        'is_available': row['s_is_available'],
        'home_delivery': row['s_home_delivery'],
        'delivery_radius_km': row['s_delivery_radius_km'],
        'delivery_fee': row['s_delivery_fee'],
        'created_at': row['s_created_at'],
      });
      return ProductSearchResult(product: product, shop: shop);
    }).toList();
  }
}
