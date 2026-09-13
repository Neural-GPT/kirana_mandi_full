class ProductModel {
  final String id;
  final String shopId;
  final String name;
  final String? categoryId;
  final double price;
  final String unit;
  final String iconId; // references IconRegistry / icons table id
  final bool isAvailable;
  final String? description;

  ProductModel({
    required this.id,
    required this.shopId,
    required this.name,
    this.categoryId,
    required this.price,
    required this.unit,
    required this.iconId,
    this.isAvailable = true,
    this.description,
  });

  ProductModel copyWith({
    String? name,
    String? categoryId,
    double? price,
    String? unit,
    String? iconId,
    bool? isAvailable,
    String? description,
  }) =>
      ProductModel(
        id: id,
        shopId: shopId,
        name: name ?? this.name,
        categoryId: categoryId ?? this.categoryId,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        iconId: iconId ?? this.iconId,
        isAvailable: isAvailable ?? this.isAvailable,
        description: description ?? this.description,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'shop_id': shopId,
        'name': name,
        'category_id': categoryId,
        'price': price,
        'unit': unit,
        'icon_id': iconId,
        'is_available': isAvailable ? 1 : 0,
        'description': description,
      };

  factory ProductModel.fromMap(Map<String, Object?> map) => ProductModel(
        id: map['id'] as String,
        shopId: map['shop_id'] as String,
        name: map['name'] as String,
        categoryId: map['category_id'] as String?,
        price: (map['price'] as num).toDouble(),
        unit: map['unit'] as String,
        iconId: map['icon_id'] as String,
        isAvailable: (map['is_available'] as int) == 1,
        description: map['description'] as String?,
      );
}
