class CartItemModel {
  final String id;
  final String customerId;
  final String shopId;
  final String shopName;
  final String productId;
  final String productName;
  final String unit;
  final double unitPrice;
  final int quantity;
  final String addedAt;

  CartItemModel({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.shopName,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
    required this.addedAt,
  });

  double get lineTotal => unitPrice * quantity;

  CartItemModel copyWith({int? quantity}) => CartItemModel(
        id: id,
        customerId: customerId,
        shopId: shopId,
        shopName: shopName,
        productId: productId,
        productName: productName,
        unit: unit,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        addedAt: addedAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'shop_id': shopId,
        'shop_name': shopName,
        'product_id': productId,
        'product_name': productName,
        'unit': unit,
        'unit_price': unitPrice,
        'quantity': quantity,
        'added_at': addedAt,
      };

  factory CartItemModel.fromMap(Map<String, Object?> map) => CartItemModel(
        id: map['id'] as String,
        customerId: map['customer_id'] as String,
        shopId: map['shop_id'] as String,
        shopName: map['shop_name'] as String,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String,
        unit: map['unit'] as String,
        unitPrice: (map['unit_price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toInt(),
        addedAt: map['added_at'] as String,
      );
}

/// A cart grouped by shop -- what the Cart screen actually renders, and
/// what checkout iterates over to create one order per shop.
class CartShopGroup {
  final String shopId;
  final String shopName;
  final List<CartItemModel> items;
  CartShopGroup({required this.shopId, required this.shopName, required this.items});

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);
}
