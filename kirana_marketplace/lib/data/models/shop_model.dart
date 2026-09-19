import '../../core/constants/app_constants.dart';

class ShopModel {
  final String id;
  final String ownerUserId;
  final String name;
  final String ownerName;
  final String phone;
  final String? altPhone;
  final String? description;
  final String? categoryId;
  final String regionId;

  // Location (PRD §8) - stored as coordinates, not just text.
  final double? latitude;
  final double? longitude;
  final String? formattedAddress;

  final String status; // pending | approved | rejected
  final bool isAvailable; // shopkeeper can temporarily mark shop unavailable

  // Delivery configuration (PRD §9 / shopkeeper dashboard)
  final bool homeDeliveryAvailable;
  final double? deliveryRadiusKm;
  final double? deliveryFee;

  final String createdAt;

  // --- White-label branding ---
  // See core/theme/shop_theme_controller.dart, which turns these into a
  // live ThemeData for a build/runtime that's locked to this shop.
  final String? logoUrl;
  final String? bannerUrl;
  final String? primaryColor; // "#RRGGBB" or "RRGGBB"
  final String? secondaryColor;

  // Short human-typeable code for the "Dynamic / On-the-Fly" white-label
  // flow (see ShopEntryScreen) -- a customer types this (or opens a link
  // that embeds it) instead of installing a shop-specific APK.
  final String shopCode;

  ShopModel({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.ownerName,
    required this.phone,
    this.altPhone,
    this.description,
    this.categoryId,
    required this.regionId,
    this.latitude,
    this.longitude,
    this.formattedAddress,
    this.status = AppConstants.shopStatusPending,
    this.isAvailable = true,
    this.homeDeliveryAvailable = false,
    this.deliveryRadiusKm,
    this.deliveryFee,
    required this.createdAt,
    this.logoUrl,
    this.bannerUrl,
    this.primaryColor,
    this.secondaryColor,
    this.shopCode = '',
  });

  bool get hasLocation => latitude != null && longitude != null;

  ShopModel copyWith({
    String? name,
    String? ownerName,
    String? phone,
    String? altPhone,
    String? description,
    String? categoryId,
    String? regionId,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? status,
    bool? isAvailable,
    bool? homeDeliveryAvailable,
    double? deliveryRadiusKm,
    double? deliveryFee,
    String? logoUrl,
    String? bannerUrl,
    String? primaryColor,
    String? secondaryColor,
  }) =>
      ShopModel(
        id: id,
        ownerUserId: ownerUserId,
        name: name ?? this.name,
        ownerName: ownerName ?? this.ownerName,
        phone: phone ?? this.phone,
        altPhone: altPhone ?? this.altPhone,
        description: description ?? this.description,
        categoryId: categoryId ?? this.categoryId,
        regionId: regionId ?? this.regionId,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        formattedAddress: formattedAddress ?? this.formattedAddress,
        status: status ?? this.status,
        isAvailable: isAvailable ?? this.isAvailable,
        homeDeliveryAvailable:
            homeDeliveryAvailable ?? this.homeDeliveryAvailable,
        deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
        deliveryFee: deliveryFee ?? this.deliveryFee,
        createdAt: createdAt,
        logoUrl: logoUrl ?? this.logoUrl,
        bannerUrl: bannerUrl ?? this.bannerUrl,
        primaryColor: primaryColor ?? this.primaryColor,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        shopCode: shopCode,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'owner_user_id': ownerUserId,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'alt_phone': altPhone,
        'description': description,
        'category_id': categoryId,
        'region_id': regionId,
        'latitude': latitude,
        'longitude': longitude,
        'formatted_address': formattedAddress,
        'status': status,
        'is_available': isAvailable ? 1 : 0,
        'home_delivery': homeDeliveryAvailable ? 1 : 0,
        'delivery_radius_km': deliveryRadiusKm,
        'delivery_fee': deliveryFee,
        'created_at': createdAt,
        'logo_url': logoUrl,
        'banner_url': bannerUrl,
        'primary_color': primaryColor,
        'secondary_color': secondaryColor,
        'shop_code': shopCode,
      };

  factory ShopModel.fromMap(Map<String, Object?> map) => ShopModel(
        id: map['id'] as String,
        ownerUserId: map['owner_user_id'] as String,
        name: map['name'] as String,
        ownerName: map['owner_name'] as String,
        phone: map['phone'] as String,
        altPhone: map['alt_phone'] as String?,
        description: map['description'] as String?,
        categoryId: map['category_id'] as String?,
        regionId: map['region_id'] as String,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        formattedAddress: map['formatted_address'] as String?,
        status: map['status'] as String,
        isAvailable: (map['is_available'] as int) == 1,
        homeDeliveryAvailable: (map['home_delivery'] as int) == 1,
        deliveryRadiusKm: (map['delivery_radius_km'] as num?)?.toDouble(),
        deliveryFee: (map['delivery_fee'] as num?)?.toDouble(),
        createdAt: map['created_at'] as String,
        logoUrl: map['logo_url'] as String?,
        bannerUrl: map['banner_url'] as String?,
        primaryColor: map['primary_color'] as String?,
        secondaryColor: map['secondary_color'] as String?,
        shopCode: map['shop_code'] as String? ?? '',
      );
}
