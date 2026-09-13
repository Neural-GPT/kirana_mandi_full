/// A single categories table backs both shop categories and product
/// categories, distinguished by [type] ('shop' | 'product'). Managed
/// exclusively by the super admin (PRD §12, §4.3).
class CategoryModel {
  final String id;
  final String name;
  final String type;
  final bool isActive;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = true,
  });

  CategoryModel copyWith({String? name, bool? isActive}) => CategoryModel(
        id: id,
        name: name ?? this.name,
        type: type,
        isActive: isActive ?? this.isActive,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'is_active': isActive ? 1 : 0,
      };

  factory CategoryModel.fromMap(Map<String, Object?> map) => CategoryModel(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String,
        isActive: (map['is_active'] as int) == 1,
      );
}
