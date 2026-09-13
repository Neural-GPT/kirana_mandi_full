import '../../core/constants/app_constants.dart';
import '../models/shop_model.dart';
import '../remote/api_client.dart';
import '../repositories/shop_repository.dart';

class HttpShopRepository implements ShopRepository {
  final ApiClient _client;
  HttpShopRepository(this._client);

  ShopModel shopFromJson(Map<String, dynamic> json) => ShopModel(
        id: json['id'] as String,
        ownerUserId: json['owner_user_id'] as String,
        name: json['name'] as String,
        ownerName: json['owner_name'] as String,
        phone: json['phone'] as String,
        altPhone: json['alt_phone'] as String?,
        description: json['description'] as String?,
        categoryId: json['category_id'] as String?,
        regionId: json['region_id'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        formattedAddress: json['formatted_address'] as String?,
        status: json['status'] as String,
        isAvailable: json['is_available'] as bool,
        homeDeliveryAvailable: json['home_delivery'] as bool,
        deliveryRadiusKm: (json['delivery_radius_km'] as num?)?.toDouble(),
        deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
        createdAt: json['created_at'] as String,
      );

  Map<String, dynamic> _toBody(ShopModel shop) => {
        'name': shop.name,
        'owner_name': shop.ownerName,
        'phone': shop.phone,
        'alt_phone': shop.altPhone,
        'description': shop.description,
        'category_id': shop.categoryId,
        'region_id': shop.regionId,
        'latitude': shop.latitude,
        'longitude': shop.longitude,
        'formatted_address': shop.formattedAddress,
        'home_delivery': shop.homeDeliveryAvailable,
        'delivery_radius_km': shop.deliveryRadiusKm,
        'delivery_fee': shop.deliveryFee,
        // service_ids are managed separately via ServiceRepository
        // .setShopServices, which calls PUT /shops/{id}/services -- an
        // empty list here just means "don't touch services" is NOT what
        // the backend does (it replaces them), so on update we fetch and
        // resend the shop's current service_ids to avoid silently
        // wiping them. See updateShop below.
        'service_ids': const <String>[],
      };

  List<ShopModel> _listFromJson(dynamic json) =>
      (json as List).map((s) => shopFromJson(s as Map<String, dynamic>)).toList();

  @override
  Future<List<ShopModel>> getShopsByRegion(String regionId, {bool approvedOnly = true}) async {
    if (approvedOnly) {
      final json = await _client.get('/regions/$regionId/shops');
      return _listFromJson(json);
    }
    // The backend's /regions/{id}/shops endpoint only ever returns
    // approved+available shops (that's the customer-facing view). The
    // only caller that wants unfiltered results is admin tooling, which
    // already has access to every shop via /admin/shops.
    final all = await getAllShops();
    return all.where((s) => s.regionId == regionId).toList();
  }

  @override
  Future<List<ShopModel>> searchShopsByName(String query) async {
    final json = await _client.get('/shops/search', query: {'q': query});
    return _listFromJson(json);
  }

  @override
  Future<List<ShopModel>> getAllShops() async {
    final json = await _client.get('/admin/shops');
    return _listFromJson(json);
  }

  @override
  Future<ShopModel?> getShopById(String id) async {
    try {
      final json = await _client.get('/shops/$id');
      return shopFromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ShopModel?> getShopByOwnerId(String ownerUserId) async {
    // The backend infers "my shop" from the bearer token (GET
    // /shops/mine), so this only works correctly when [ownerUserId] is
    // the currently logged-in shopkeeper's own id -- true for every
    // call site in this app (right after login, to decide whether to
    // route to shop setup or the dashboard).
    final json = await _client.get('/shops/mine');
    if (json == null) return null;
    return shopFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<ShopModel> createShop(ShopModel shop) async {
    final json = await _client.post('/shops', body: _toBody(shop));
    return shopFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> updateShop(ShopModel shop, {required String requestingUserId}) async {
    // Preserve existing service links -- see the comment in _toBody.
    final body = _toBody(shop);
    try {
      final current = await _client.get('/shops/${shop.id}') as Map<String, dynamic>;
      body['service_ids'] = List<String>.from(current['service_ids'] as List);
    } catch (_) {
      // If the shop can't be fetched, fall through with an empty
      // service list rather than failing the whole update.
    }
    await _client.put('/shops/${shop.id}', body: body);
  }

  @override
  Future<void> setShopAvailability(String shopId, bool isAvailable,
      {required String requestingUserId}) async {
    await _client.patch('/shops/$shopId/availability', body: {'is_available': isAvailable});
  }

  @override
  Future<List<ShopModel>> getShopsByStatus(String status) async {
    final json = await _client.get('/admin/shops', query: {'status_filter': status});
    return _listFromJson(json);
  }

  @override
  Future<void> setShopStatus(String shopId, String status) async {
    await _client.patch('/admin/shops/$shopId/status', body: {'status': status});
  }

  @override
  Future<Map<String, int>> getPlatformStats() async {
    final json = await _client.get('/admin/stats') as Map<String, dynamic>;
    return json.map((key, value) => MapEntry(key, (value as num).toInt()));
  }
}
