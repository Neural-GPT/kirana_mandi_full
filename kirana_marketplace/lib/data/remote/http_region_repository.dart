import '../models/region_model.dart';
import '../remote/api_client.dart';
import '../repositories/region_repository.dart';

class HttpRegionRepository implements RegionRepository {
  final ApiClient _client;
  HttpRegionRepository(this._client);

  RegionModel _fromJson(Map<String, dynamic> json) => RegionModel(
        id: json['id'] as String,
        name: json['name'] as String,
        isActive: json['is_active'] as bool,
      );

  @override
  Future<List<RegionModel>> getAllRegions({bool activeOnly = true}) async {
    final json = await _client.get('/regions', query: {'active_only': activeOnly});
    return (json as List).map((r) => _fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<RegionModel?> getRegionById(String id) async {
    try {
      final json = await _client.get('/regions/$id');
      return _fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> createRegion(RegionModel region) async {
    // The backend's POST /regions is find-or-create (dedupes by name),
    // which is a strict superset of "create" -- fine for an admin
    // explicitly adding a new region too.
    await _client.post('/regions', body: {'name': region.name});
  }

  @override
  Future<void> updateRegion(RegionModel region) async {
    await _client.put('/regions/${region.id}', body: {'name': region.name});
  }

  @override
  Future<void> setRegionActive(String id, bool isActive) async {
    await _client.patch('/regions/$id/active', body: {'is_active': isActive});
  }

  @override
  Future<RegionModel> findOrCreateByName(String name) async {
    final json = await _client.post('/regions', body: {'name': name});
    return _fromJson(json as Map<String, dynamic>);
  }
}
