import '../models/product_model.dart';
import '../remote/api_client.dart';
import '../repositories/product_repository.dart';
import 'http_shop_repository.dart';

class HttpProductRepository implements ProductRepository {
  final ApiClient _client;
  // Reused purely for its JSON<->ShopModel mapping helper -- avoids
  // duplicating that logic here.
  final HttpShopRepository _shopMapper;

  HttpProductRepository(this._client) : _shopMapper = HttpShopRepository(_client);

  ProductModel _fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        name: json['name'] as String,
        categoryId: json['category_id'] as String?,
        price: (json['price'] as num).toDouble(),
        unit: json['unit'] as String,
        iconId: (json['icon_id'] as String?) ?? 'generic_item_01',
        isAvailable: json['is_available'] as bool,
        description: json['description'] as String?,
      );

  Map<String, dynamic> _toBody(ProductModel product) => {
        'name': product.name,
        'category_id': product.categoryId,
        'price': product.price,
        'unit': product.unit,
        'icon_id': product.iconId,
        'description': product.description,
        'is_available': product.isAvailable,
      };

  ProductSearchResult _searchResultFromJson(Map<String, dynamic> json) =>
      ProductSearchResult(
        product: _fromJson(json['product'] as Map<String, dynamic>),
        shop: _shopMapper.shopFromJson(json['shop'] as Map<String, dynamic>),
      );

  @override
  Future<List<ProductModel>> getProductsByShop(String shopId, {bool availableOnly = false}) async {
    final json = await _client.get('/shops/$shopId/products');
    final products =
        (json as List).map((p) => _fromJson(p as Map<String, dynamic>)).toList();
    return availableOnly ? products.where((p) => p.isAvailable).toList() : products;
  }

  @override
  Future<ProductModel?> getProductById(String id) async {
    try {
      final json = await _client.get('/products/$id');
      return _fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ProductModel> createProduct(ProductModel product,
      {required String requestingUserId}) async {
    final json =
        await _client.post('/shops/${product.shopId}/products', body: _toBody(product));
    return _fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> updateProduct(ProductModel product, {required String requestingUserId}) async {
    await _client.put('/products/${product.id}', body: _toBody(product));
  }

  @override
  Future<void> deleteProduct(String productId, {required String requestingUserId}) async {
    await _client.delete('/products/$productId');
  }

  @override
  Future<void> setProductAvailability(String productId, bool isAvailable,
      {required String requestingUserId}) async {
    final product = await getProductById(productId);
    if (product == null) return;
    await updateProduct(product.copyWith(isAvailable: isAvailable),
        requestingUserId: requestingUserId);
  }

  @override
  Future<List<ProductSearchResult>> searchProductsByName(String query, {String? regionId}) async {
    final json = await _client.get('/products/search', query: {
      'q': query,
      if (regionId != null) 'region_id': regionId,
    });
    return (json as List)
        .map((r) => _searchResultFromJson(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ProductSearchResult>> getAllProductsAcrossShops({int limit = 200}) async {
    final json = await _client.get('/admin/products', query: {'limit': limit});
    return (json as List)
        .map((r) => _searchResultFromJson(r as Map<String, dynamic>))
        .toList();
  }
}
