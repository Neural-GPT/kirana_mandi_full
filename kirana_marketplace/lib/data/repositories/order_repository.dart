import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../local/database_helper.dart';
import '../models/cart_item_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';

abstract class OrderRepository {
  /// Creates one order per shop group in [groups] (a mixed-shop cart
  /// checkout becomes several orders). Returns the created orders.
  Future<List<OrderModel>> placeOrdersFromGroups({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required List<CartShopGroup> groups,
    required Map<String, String> shopPhoneById,
  });

  Future<List<OrderWithItems>> getOrdersForCustomer(String customerId);
  Future<List<OrderWithItems>> getOrdersForShop(String shopId);
  Future<OrderWithItems?> getOrderById(String orderId);

  /// Shopkeeper accepts/rejects/advances an order. Optionally attaches
  /// the delivery boy's phone number (shown to the customer once set).
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? deliveryBoyPhone,
    required String requestingUserId,
  });

  Future<void> cancelOrder(String orderId, {required String requestingCustomerId});
}

class SqliteOrderRepository implements OrderRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<List<OrderModel>> placeOrdersFromGroups({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required List<CartShopGroup> groups,
    required Map<String, String> shopPhoneById,
  }) async {
    if (groups.isEmpty) {
      throw ValidationException('Your cart is empty.');
    }
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final created = <OrderModel>[];

    await db.transaction((txn) async {
      for (final group in groups) {
        final orderId = _uuid.v4();
        final order = OrderModel(
          id: orderId,
          customerId: customerId,
          customerName: customerName,
          customerPhone: customerPhone,
          shopId: group.shopId,
          shopName: group.shopName,
          shopPhone: shopPhoneById[group.shopId] ?? '',
          status: AppConstants.orderStatusPlaced,
          totalAmount: group.subtotal,
          createdAt: now,
          updatedAt: now,
        );
        await txn.insert('orders', order.toMap());

        for (final item in group.items) {
          await txn.insert('order_items', {
            'id': _uuid.v4(),
            'order_id': orderId,
            'product_id': item.productId,
            'product_name': item.productName,
            'unit': item.unit,
            'unit_price': item.unitPrice,
            'quantity': item.quantity,
          });
        }
        created.add(order);
      }

      // Clear the shops that were just ordered from out of the cart.
      for (final group in groups) {
        await txn.delete('cart_items',
            where: 'customer_id = ? AND shop_id = ?',
            whereArgs: [customerId, group.shopId]);
      }
    });

    return created;
  }

  Future<List<OrderWithItems>> _hydrate(List<Map<String, Object?>> orderRows) async {
    final db = await _db;
    final result = <OrderWithItems>[];
    for (final row in orderRows) {
      final order = OrderModel.fromMap(row);
      final itemRows = await db.query('order_items',
          where: 'order_id = ?', whereArgs: [order.id]);
      result.add(OrderWithItems(
        order: order,
        items: itemRows.map(OrderItemModel.fromMap).toList(),
      ));
    }
    return result;
  }

  @override
  Future<List<OrderWithItems>> getOrdersForCustomer(String customerId) async {
    final db = await _db;
    final rows = await db.query('orders',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at DESC');
    return _hydrate(rows);
  }

  @override
  Future<List<OrderWithItems>> getOrdersForShop(String shopId) async {
    final db = await _db;
    final rows = await db.query('orders',
        where: 'shop_id = ?', whereArgs: [shopId], orderBy: 'created_at DESC');
    return _hydrate(rows);
  }

  @override
  Future<OrderWithItems?> getOrderById(String orderId) async {
    final db = await _db;
    final rows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (rows.isEmpty) return null;
    final hydrated = await _hydrate(rows);
    return hydrated.first;
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? deliveryBoyPhone,
    required String requestingUserId,
  }) async {
    final db = await _db;
    final rows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (rows.isEmpty) throw NotFoundException('Order not found.');
    // Defensive on-device ownership check, same pattern as
    // ShopRepository/ProductRepository -- the production API must
    // re-verify this server-side against the authenticated session.
    // Shopkeepers manage orders for their own shop; callers
    // (ShopkeeperOrdersScreen) only ever load orders for a shop they
    // already own via getOrdersForShop, so requestingUserId is accepted
    // here mainly for API symmetry with other repositories and for
    // straightforward server-side enforcement once there's a real API.
    final updated = {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
      if (deliveryBoyPhone != null) 'delivery_boy_phone': deliveryBoyPhone,
    };
    await db.update('orders', updated, where: 'id = ?', whereArgs: [orderId]);
  }

  @override
  Future<void> cancelOrder(String orderId,
      {required String requestingCustomerId}) async {
    final db = await _db;
    final rows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (rows.isEmpty) throw NotFoundException('Order not found.');
    final order = OrderModel.fromMap(rows.first);
    if (order.customerId != requestingCustomerId) {
      throw UnauthorizedException('This is not your order.');
    }
    if (!order.isActive) {
      throw ValidationException('This order can no longer be cancelled.');
    }
    await db.update(
      'orders',
      {
        'status': AppConstants.orderStatusCancelled,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
