import '../../core/constants/app_constants.dart';

/// One order = one shop's worth of items from a customer's cart. A cart
/// spanning multiple shops becomes multiple OrderModels (see
/// OrderRepository.placeOrdersFromCart) so each shopkeeper only ever
/// sees orders for their own shop.
class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String shopId;
  final String shopName;
  final String shopPhone;
  final String status;
  final String? deliveryBoyPhone;
  final double totalAmount;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.shopId,
    required this.shopName,
    required this.shopPhone,
    this.status = AppConstants.orderStatusPlaced,
    this.deliveryBoyPhone,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => AppConstants.activeOrderStatuses.contains(status);

  OrderModel copyWith({
    String? status,
    String? deliveryBoyPhone,
    String? updatedAt,
  }) =>
      OrderModel(
        id: id,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        shopId: shopId,
        shopName: shopName,
        shopPhone: shopPhone,
        status: status ?? this.status,
        deliveryBoyPhone: deliveryBoyPhone ?? this.deliveryBoyPhone,
        totalAmount: totalAmount,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'shop_id': shopId,
        'shop_name': shopName,
        'shop_phone': shopPhone,
        'status': status,
        'delivery_boy_phone': deliveryBoyPhone,
        'total_amount': totalAmount,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory OrderModel.fromMap(Map<String, Object?> map) => OrderModel(
        id: map['id'] as String,
        customerId: map['customer_id'] as String,
        customerName: map['customer_name'] as String,
        customerPhone: map['customer_phone'] as String,
        shopId: map['shop_id'] as String,
        shopName: map['shop_name'] as String,
        shopPhone: map['shop_phone'] as String,
        status: map['status'] as String,
        deliveryBoyPhone: map['delivery_boy_phone'] as String?,
        totalAmount: (map['total_amount'] as num).toDouble(),
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );
}
