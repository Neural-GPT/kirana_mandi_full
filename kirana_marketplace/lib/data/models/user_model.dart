class UserModel {
  final String id;
  final String phone;
  final String? name;
  final String role; // customer | shopkeeper | admin
  final String createdAt;

  UserModel({
    required this.id,
    required this.phone,
    this.name,
    required this.role,
    required this.createdAt,
  });

  UserModel copyWith({String? name, String? role}) => UserModel(
        id: id,
        phone: phone,
        name: name ?? this.name,
        role: role ?? this.role,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role,
        'created_at': createdAt,
      };

  factory UserModel.fromMap(Map<String, Object?> map) => UserModel(
        id: map['id'] as String,
        phone: map['phone'] as String,
        name: map['name'] as String?,
        role: map['role'] as String,
        createdAt: map['created_at'] as String,
      );
}
