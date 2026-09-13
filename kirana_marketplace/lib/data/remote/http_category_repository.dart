import '../models/category_model.dart';
import '../remote/api_client.dart';
import '../repositories/category_repository.dart';

class HttpCategoryRepository implements CategoryRepository {
  final ApiClient _client;
  HttpCategoryRepository(this._client);

  CategoryModel _fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        isActive: json['is_active'] as bool,
      );

  @override
  Future<List<CategoryModel>> getByType(String type, {bool activeOnly = true}) async {
    final json = await _client
        .get('/categories', query: {'type': type, 'active_only': activeOnly});
    return (json as List).map((c) => _fromJson(c as Map<String, dynamic>)).toList();
  }

  @override
  Future<CategoryModel?> getById(String id) async {
    // No single-category lookup endpoint -- categories are a small,
    // fully-loaded reference list, so filtering client-side out of
    // both types is cheap and avoids adding an endpoint for a lookup
    // nothing in the app actually calls directly today.
    for (final type in const ['shop', 'product']) {
      final matches = await getByType(type, activeOnly: false);
      for (final c in matches) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  @override
  Future<void> create(CategoryModel category) async {
    await _client.post('/categories', body: {
      'name': category.name,
      'type': category.type,
    });
  }

  @override
  Future<void> update(CategoryModel category) async {
    await _client.patch('/categories/${category.id}', body: {
      'name': category.name,
      'type': category.type,
    });
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    await _client.patch('/categories/$id/active', body: {'is_active': isActive});
  }
}
