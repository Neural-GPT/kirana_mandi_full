import '../models/product_icon_model.dart';
import '../remote/api_client.dart';
import '../repositories/icon_repository.dart';

class HttpIconRepository implements IconRepository {
  final ApiClient _client;
  HttpIconRepository(this._client);

  ProductIconModel _fromJson(Map<String, dynamic> json) => ProductIconModel(
        id: json['id'] as String,
        label: json['label'] as String,
        categoryId: json['category_id'] as String?,
        isActive: json['is_active'] as bool,
      );

  @override
  Future<List<ProductIconModel>> getAllIcons({bool activeOnly = true}) async {
    final json = await _client.get('/icons', query: {'active_only': activeOnly});
    return (json as List).map((i) => _fromJson(i as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<ProductIconModel>> getIconsByCategory(String categoryId) async {
    final json = await _client.get('/icons', query: {'category_id': categoryId});
    return (json as List).map((i) => _fromJson(i as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> create(ProductIconModel icon) async {
    await _client.post('/icons', body: {
      'id': icon.id,
      'label': icon.label,
      'category_id': icon.categoryId,
    });
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    await _client.patch('/icons/$id/active', body: {'is_active': isActive});
  }
}
