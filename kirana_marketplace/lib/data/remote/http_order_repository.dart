import '../models/cart_item_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../remote/api_client.dart';
import '../repositories/order_repository.dart';

class HttpOrderRepository implements OrderRepository {
  final ApiClient _client;
  HttpOrderRepository(this._client);

  OrderModel _orderFromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        customerName: json['customer_name'] as String,
        customerPhone: json['customer_phone'] as String,
        shopId: json['shop_id'] as String,
        shopName: json['shop_name'] as String,
        shopPhone: json['shop_phone'] as String,
        status: json['status'] as String,
        deliveryBoyPhone: json['delivery_boy_phone'] as String?,
        totalAmount: (json['total_amount'] as num).toDouble(),
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
      );

  OrderItemModel _itemFromJson(Map<String, dynamic> json, String orderId) => OrderItemModel(
        id: json['id'] as String,
        orderId: orderId,
        productId: json['product_id'] as String?,
        productName: json['product_name'] as String,
        unit: json['unit'] as String,
        unitPrice: (json['unit_price'] as num).toDouble(),
        quantity: (json['quantity'] as num).toInt(),
      );

  OrderWithItems _withItemsFromJson(Map<String, dynamic> json) {
    final order = _orderFromJson(json);
    final items = (json['items'] as List)
        .map((i) => _itemFromJson(i as Map<String, dynamic>, order.id))
        .toList();
    return OrderWithItems(order: order, items: items);
  }

  @override
  Future<List<OrderModel>> placeOrdersFromGroups({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required List<CartShopGroup> groups,
    required Map<String, String> shopPhoneById,
  }) async {
    // The backend checks out whatever is already in the customer's
    // server-side cart for these shop ids (see HttpCartRepository --
    // items were already added there before checkout is ever called),
    // so [groups]' item contents and the customer/phone args aren't
    // sent; the backend derives customer identity from the bearer token
    // and shop phone from its own shop record.
    final json = await _client.post('/orders/checkout', body: {
      'shop_ids': groups.map((g) => g.shopId).toList(),
    });
    return (json as List).map((o) => _orderFromJson(o as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<OrderWithItems>> getOrdersForCustomer(String customerId) async {
    final json = await _client.get('/orders/mine');
    return (json as List)
        .map((o) => _withItemsFromJson(o as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<OrderWithItems>> getOrdersForShop(String shopId) async {
    final json = await _client.get('/shops/$shopId/orders');
    return (json as List)
        .map((o) => _withItemsFromJson(o as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderWithItems?> getOrderById(String orderId) async {
    try {
      final json = await _client.get('/orders/$orderId');
      return _withItemsFromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? deliveryBoyPhone,
    required String requestingUserId,
  }) async {
    await _client.patch('/orders/$orderId/status', body: {
      'status': status,
      if (deliveryBoyPhone != null) 'delivery_boy_phone': deliveryBoyPhone,
    });
  }

  @override
  Future<void> cancelOrder(String orderId, {required String requestingCustomerId}) async {
    await _client.post('/orders/$orderId/cancel');
  }
}
