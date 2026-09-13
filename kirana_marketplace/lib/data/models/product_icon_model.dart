/// A row in the built-in icon library. Only the [id] (e.g. "milk_01") is
/// meaningful for rendering -- it's resolved to a bundled Material icon via
/// IconRegistry. This model + table just carries the human-readable label
/// and category grouping, so the super admin can browse/manage the library
/// without touching binary image data (PRD §11).
class ProductIconModel {
  final String id;
  final String label;
  final String? categoryId;
  final bool isActive;

  ProductIconModel({
    required this.id,
    required this.label,
    this.categoryId,
    this.isActive = true,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'label': label,
        'category_id': categoryId,
        'is_active': isActive ? 1 : 0,
      };

  factory ProductIconModel.fromMap(Map<String, Object?> map) =>
      ProductIconModel(
        id: map['id'] as String,
        label: map['label'] as String,
        categoryId: map['category_id'] as String?,
        isActive: (map['is_active'] as int) == 1,
      );
}
