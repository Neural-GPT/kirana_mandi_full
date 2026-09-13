import '../models/service_model.dart';
import '../remote/api_client.dart';
import '../repositories/service_repository.dart';

class HttpServiceRepository implements ServiceRepository {
  final ApiClient _client;
  HttpServiceRepository(this._client);

  ServiceModel _fromJson(Map<String, dynamic> json) => ServiceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        isActive: json['is_active'] as bool,
      );

  @override
  Future<List<ServiceModel>> getAllServices({bool activeOnly = true}) async {
    final json = await _client.get('/services', query: {'active_only': activeOnly});
    return (json as List).map((s) => _fromJson(s as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> create(ServiceModel service) async {
    await _client.post('/services', body: {'name': service.name});
  }

  @override
  Future<void> update(ServiceModel service) async {
    await _client.put('/services/${service.id}', body: {'name': service.name});
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    await _client.patch('/services/$id/active', body: {'is_active': isActive});
  }

  @override
  Future<List<String>> getServiceIdsForShop(String shopId) async {
    // ShopOut already carries service_ids -- no need for a dedicated
    // endpoint just to read them back.
    final json = await _client.get('/shops/$shopId');
    return List<String>.from(json['service_ids'] as List);
  }

  @override
  Future<void> setShopServices(String shopId, List<String> serviceIds) async {
    await _client.put('/shops/$shopId/services', body: {'service_ids': serviceIds});
  }
}
