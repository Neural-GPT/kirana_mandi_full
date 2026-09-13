import '../models/cart_item_model.dart';
import '../remote/api_client.dart';
import '../repositories/cart_repository.dart';

/// Talks to the backend's /cart endpoints instead of the on-device
/// `cart_items` table. Note the backend infers the customer from the
/// bearer token rather than a passed-in id, so [customerId] arguments
/// here are only used for the return values' shape, not sent to the
/// server -- every call site in the app already only ever operates on
/// "my own" cart anyway.
class HttpCartRepository implements CartRepository {
  final ApiClient _client;
  HttpCartRepository(this._client);

  CartItemModel _fromJson(Map<String, dynamic> json, String customerId) => CartItemModel(
        id: json['id'] as String,
        customerId: customerId,
        shopId: json['shop_id'] as String,
        shopName: json['shop_name'] as String,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        unit: json['unit'] as String,
        unitPrice: (json['unit_price'] as num).toDouble(),
        quantity: (json['quantity'] as num).toInt(),
        addedAt: json['added_at'] as String,
      );

  @override
  Future<List<CartItemModel>> getCartItems(String customerId) async {
    final json = await _client.get('/cart');
    return (json as List)
        .map((c) => _fromJson(c as Map<String, dynamic>, customerId))
        .toList();
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
    await _client.post('/cart/items', body: {
      'shop_id': shopId,
      'shop_name': shopName,
      'product_id': productId,
      'product_name': productName,
      'unit': unit,
      'unit_price': unitPrice,
      'quantity': quantity,
    });
  }

  @override
  Future<void> setQuantity({
    required String customerId,
    required String productId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      await removeItem(customerId: customerId, productId: productId);
      return;
    }
    await _client.patch('/cart/items/$productId', body: {'quantity': quantity});
  }

  @override
  Future<void> removeItem({required String customerId, required String productId}) async {
    await _client.delete('/cart/items/$productId');
  }

  @override
  Future<void> clearShop({required String customerId, required String shopId}) async {
    final items = await getCartItems(customerId);
    for (final item in items.where((i) => i.shopId == shopId)) {
      await removeItem(customerId: customerId, productId: item.productId);
    }
  }

  @override
  Future<void> clearAll(String customerId) async {
    final items = await getCartItems(customerId);
    for (final item in items) {
      await removeItem(customerId: customerId, productId: item.productId);
    }
  }
}
