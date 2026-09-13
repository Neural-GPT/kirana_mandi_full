import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../models/cart_item_model.dart';

abstract class CartRepository {
  Future<List<CartItemModel>> getCartItems(String customerId);

  /// Adds [quantity] of a product to the cart, or increases the existing
  /// line's quantity if that product is already in the cart.
  Future<void> addOrIncrement({
    required String customerId,
    required String shopId,
    required String shopName,
    required String productId,
    required String productName,
    required String unit,
    required double unitPrice,
    int quantity = 1,
  });

  Future<void> setQuantity({
    required String customerId,
    required String productId,
    required int quantity,
  });

  Future<void> removeItem({
    required String customerId,
    required String productId,
  });

  Future<void> clearShop({required String customerId, required String shopId});
  Future<void> clearAll(String customerId);
}

class SqliteCartRepository implements CartRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<List<CartItemModel>> getCartItems(String customerId) async {
    final db = await _db;
    final rows = await db.query('cart_items',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'shop_name ASC, added_at ASC');
    return rows.map(CartItemModel.fromMap).toList();
  }

  @override
  Future<void> addOrIncrement({
    required String customerId,
    required String shopId,
    required String shopName,
    required String productId,
    required String productName,
    required String unit,
    required double unitPrice,
    int quantity = 1,
  }) async {
    final db = await _db;
    final existing = await db.query('cart_items',
        where: 'customer_id = ? AND product_id = ?',
        whereArgs: [customerId, productId]);

    if (existing.isNotEmpty) {
      final current = CartItemModel.fromMap(existing.first);
      await db.update(
        'cart_items',
        {'quantity': current.quantity + quantity},
        where: 'id = ?',
        whereArgs: [current.id],
      );
      return;
    }

    await db.insert('cart_items', {
      'id': _uuid.v4(),
      'customer_id': customerId,
      'shop_id': shopId,
      'shop_name': shopName,
      'product_id': productId,
      'product_name': productName,
      'unit': unit,
      'unit_price': unitPrice,
      'quantity': quantity,
      'added_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> setQuantity({
    required String customerId,
    required String productId,
    required int quantity,
  }) async {
    final db = await _db;
    if (quantity <= 0) {
      await removeItem(customerId: customerId, productId: productId);
      return;
    }
    await db.update(
      'cart_items',
      {'quantity': quantity},
      where: 'customer_id = ? AND product_id = ?',
      whereArgs: [customerId, productId],
    );
  }

  @override
  Future<void> removeItem({
    required String customerId,
    required String productId,
  }) async {
    final db = await _db;
    await db.delete('cart_items',
        where: 'customer_id = ? AND product_id = ?',
        whereArgs: [customerId, productId]);
  }

  @override
  Future<void> clearShop({required String customerId, required String shopId}) async {
    final db = await _db;
    await db.delete('cart_items',
        where: 'customer_id = ? AND shop_id = ?', whereArgs: [customerId, shopId]);
  }

  @override
  Future<void> clearAll(String customerId) async {
    final db = await _db;
    await db.delete('cart_items', where: 'customer_id = ?', whereArgs: [customerId]);
  }
}
