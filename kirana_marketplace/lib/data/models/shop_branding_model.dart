/// Everything a client needs to skin itself for one shop -- mirrors the
/// backend's `GET /shops/{shop_id}/branding` response (see
/// kirana_backend/app/schemas.py ShopBrandingOut). Deliberately smaller
/// than [ShopModel]: just the public, white-labeling-relevant subset, so
/// it can be fetched before any user is logged in (e.g. a fresh
/// white-label install's very first frame).
class ShopBrandingModel {
  final String shopId;
  final String shopName;
  final String? logoUrl;
  final String? bannerUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String regionId;
  final String contactNumber;
  final String status; // pending | approved | rejected
  final String shopCode;

  const ShopBrandingModel({
    required this.shopId,
    required this.shopName,
    this.logoUrl,
    this.bannerUrl,
    this.primaryColor,
    this.secondaryColor,
    required this.regionId,
    required this.contactNumber,
    required this.status,
    required this.shopCode,
  });

  bool get isApproved => status == 'approved';

  factory ShopBrandingModel.fromJson(Map<String, dynamic> json) => ShopBrandingModel(
        shopId: json['shop_id'] as String,
        shopName: json['shop_name'] as String,
        logoUrl: json['logo_url'] as String?,
        bannerUrl: json['banner_url'] as String?,
        primaryColor: json['primary_color'] as String?,
        secondaryColor: json['secondary_color'] as String?,
        regionId: json['region_id'] as String,
        contactNumber: json['contact_number'] as String,
        status: json['status'] as String,
        shopCode: json['shop_code'] as String,
      );

  /// Builds branding straight from a [ShopModel] -- used by
  /// [SqliteTenantRepository] (offline/on-device mode) so both
  /// repository backends can serve [ShopThemeController] the same shape.
  factory ShopBrandingModel.fromShop({
    required String id,
    required String name,
    String? logoUrl,
    String? bannerUrl,
    String? primaryColor,
    String? secondaryColor,
    required String regionId,
    required String phone,
    required String status,
    required String shopCode,
  }) =>
      ShopBrandingModel(
        shopId: id,
        shopName: name,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        regionId: regionId,
        contactNumber: phone,
        status: status,
        shopCode: shopCode,
      );
}
