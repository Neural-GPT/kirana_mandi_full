import 'order_model.dart';

class OrderItemModel {
  final String id;
  final String orderId;
  final String? productId;
  final String productName;
  final String unit;
  final double unitPrice;
  final int quantity;

  OrderItemModel({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;

  Map<String, Object?> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'product_name': productName,
        'unit': unit,
        'unit_price': unitPrice,
        'quantity': quantity,
      };

  factory OrderItemModel.fromMap(Map<String, Object?> map) => OrderItemModel(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        productId: map['product_id'] as String?,
        productName: map['product_name'] as String,
        unit: map['unit'] as String,
        unitPrice: (map['unit_price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toInt(),
      );
}

/// An order plus its line items, since the two are almost always read
/// and displayed together.
class OrderWithItems {
  final OrderModel order;
  final List<OrderItemModel> items;
  OrderWithItems({required this.order, required this.items});
}
