class RegionModel {
  final String id;
  final String name;
  final String? parentId; // simple one-level hierarchy, e.g. Agra -> Krishna Nagar
  final bool isActive;

  RegionModel({
    required this.id,
    required this.name,
    this.parentId,
    this.isActive = true,
  });

  RegionModel copyWith({String? name, String? parentId, bool? isActive}) =>
      RegionModel(
        id: id,
        name: name ?? this.name,
        parentId: parentId ?? this.parentId,
        isActive: isActive ?? this.isActive,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'parent_id': parentId,
        'is_active': isActive ? 1 : 0,
      };

  factory RegionModel.fromMap(Map<String, Object?> map) => RegionModel(
        id: map['id'] as String,
        name: map['name'] as String,
        parentId: map['parent_id'] as String?,
        isActive: (map['is_active'] as int) == 1,
      );
}
