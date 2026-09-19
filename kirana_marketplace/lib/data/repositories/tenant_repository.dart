import '../../core/errors/exceptions.dart';
import '../models/shop_branding_model.dart';
import 'shop_repository.dart';

/// Resolves a white-label tenant: fetches one shop's branding, and turns
/// a shopkeeper-shareable Shop Code into a shop_id (the "Dynamic /
/// On-the-Fly UI" flow -- see ShopEntryScreen). Bound to either
/// [HttpTenantRepository] or [SqliteTenantRepository] in main.dart, the
/// same abstract-repository pattern every other data source in this app
/// follows.
abstract class TenantRepository {
  Future<ShopBrandingModel> getBranding(String shopId);
  Future<String> resolveShopCode(String shopCode);
}

class HttpTenantRepository implements TenantRepository {
  // Reuses the same underlying ApiClient the other Http*Repository
  // classes share; kept as `dynamic`-free by depending on ApiClient's
  // narrow `get` surface only (no auth needed for these two endpoints --
  // both are public on the backend so a freshly-installed white-label
  // build can call them before any user has logged in).
  final dynamic _client;
  HttpTenantRepository(this._client);

  @override
  Future<ShopBrandingModel> getBranding(String shopId) async {
    final json = await _client.get('/shops/$shopId/branding');
    return ShopBrandingModel.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<String> resolveShopCode(String shopCode) async {
    final json = await _client.get('/shops/by-code/${shopCode.trim().toUpperCase()}');
    final map = json as Map<String, dynamic>;
    return map['shop_id'] as String;
  }
}

/// Offline/on-device fallback: derives the same [ShopBrandingModel] shape
/// straight from the local `shops` table via [ShopRepository], so
/// white-labeling works identically whether the app is pointed at the
/// FastAPI backend or running fully offline (SQLite demo mode).
class SqliteTenantRepository implements TenantRepository {
  final ShopRepository _shopRepository;
  SqliteTenantRepository(this._shopRepository);

  @override
  Future<ShopBrandingModel> getBranding(String shopId) async {
    final shop = await _shopRepository.getShopById(shopId);
    if (shop == null) throw NotFoundException('Shop not found.');
    return ShopBrandingModel.fromShop(
      id: shop.id,
      name: shop.name,
      logoUrl: shop.logoUrl,
      bannerUrl: shop.bannerUrl,
      primaryColor: shop.primaryColor,
      secondaryColor: shop.secondaryColor,
      regionId: shop.regionId,
      phone: shop.phone,
      status: shop.status,
      shopCode: shop.shopCode,
    );
  }

  @override
  Future<String> resolveShopCode(String shopCode) async {
    final all = await _shopRepository.getAllShops();
    final normalized = shopCode.trim().toUpperCase();
    final match = all.where((s) => s.shopCode.toUpperCase() == normalized).toList();
    if (match.isEmpty) throw NotFoundException('No shop found for that code.');
    return match.first.id;
  }
}
