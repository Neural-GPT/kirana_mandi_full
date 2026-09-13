import '../models/call_log_model.dart';
import '../remote/api_client.dart';
import '../repositories/call_log_repository.dart';

class HttpCallLogRepository implements CallLogRepository {
  final ApiClient _client;
  HttpCallLogRepository(this._client);

  CallLogModel _fromJson(Map<String, dynamic> json) => CallLogModel(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        callerLabel: json['caller_label'] as String?,
        calledAt: json['called_at'] as String,
      );

  @override
  Future<void> logCall({required String shopId, String? callerLabel}) async {
    await _client.post('/calls', body: {
      'shop_id': shopId,
      if (callerLabel != null) 'caller_label': callerLabel,
    });
  }

  @override
  Future<List<CallLogModel>> getCallsForShop(String shopId, {int limit = 100}) async {
    final json = await _client.get('/shops/$shopId/calls', query: {'limit': limit});
    return (json as List).map((c) => _fromJson(c as Map<String, dynamic>)).toList();
  }

  @override
  Future<int> getCallCountSince(String shopId, DateTime since) async {
    final json = await _client
        .get('/shops/$shopId/calls/count', query: {'since': since.toIso8601String()});
    return (json['count'] as num).toInt();
  }
}
