/// A selectable service type (e.g. "Home Delivery", "Bulk Orders").
/// The library of available types is managed by the super admin;
/// shopkeepers pick from it rather than typing free text (PRD §9).
class ServiceModel {
  final String id;
  final String name;
  final bool isActive;

  ServiceModel({required this.id, required this.name, this.isActive = true});

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'is_active': isActive ? 1 : 0,
      };

  factory ServiceModel.fromMap(Map<String, Object?> map) => ServiceModel(
        id: map['id'] as String,
        name: map['name'] as String,
        isActive: (map['is_active'] as int) == 1,
      );
}
