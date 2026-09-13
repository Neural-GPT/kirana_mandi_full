/// One line item from a shopkeeper's "today's sales" entry -- a product
/// name, the quantity sold, and the price it sold at (captured at entry
/// time so later price changes don't rewrite sales history).
class SaleItemModel {
  final String id;
  final String shopId;
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final String saleDate; // yyyy-MM-dd, local calendar date of the sale
  final String createdAt;

  SaleItemModel({
    required this.id,
    required this.shopId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.saleDate,
    required this.createdAt,
  });

  double get revenue => quantity * unitPrice;

  Map<String, Object?> toMap() => {
        'id': id,
        'shop_id': shopId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'sale_date': saleDate,
        'created_at': createdAt,
      };

  factory SaleItemModel.fromMap(Map<String, Object?> map) => SaleItemModel(
        id: map['id'] as String,
        shopId: map['shop_id'] as String,
        productId: map['product_id'] as String?,
        productName: map['product_name'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        saleDate: map['sale_date'] as String,
        createdAt: map['created_at'] as String,
      );
}
