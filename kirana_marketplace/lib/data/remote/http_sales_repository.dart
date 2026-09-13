import '../models/sale_item_model.dart';
import '../remote/api_client.dart';
import '../repositories/sales_repository.dart';

class HttpSalesRepository implements SalesRepository {
  final ApiClient _client;
  HttpSalesRepository(this._client);

  // The backend's `date` fields are plain "YYYY-MM-DD" strings, so we
  // deliberately don't send time-of-day or timezone here.
  String _dateOnly(DateTime d) => d.toIso8601String().split('T').first;

  SaleItemModel _fromJson(Map<String, dynamic> json) => SaleItemModel(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        productId: json['product_id'] as String?,
        productName: json['product_name'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unit_price'] as num).toDouble(),
        saleDate: json['sale_date'] as String,
        createdAt: json['created_at'] as String,
      );

  @override
  Future<void> recordDailySales({
    required String shopId,
    required DateTime date,
    required List<SaleEntryInput> entries,
  }) async {
    await _client.post('/shops/$shopId/sales', body: {
      'sale_date': _dateOnly(date),
      'entries': entries
          .map((e) => {
                'product_id': e.productId,
                'product_name': e.productName,
                'quantity': e.quantity,
                'unit_price': e.unitPrice,
              })
          .toList(),
    });
  }

  @override
  Future<List<SaleItemModel>> getSaleItemsForDate(String shopId, DateTime date) async {
    final json =
        await _client.get('/shops/$shopId/sales', query: {'sale_date': _dateOnly(date)});
    return (json as List).map((s) => _fromJson(s as Map<String, dynamic>)).toList();
  }

  @override
  Future<double> getRevenueForDate(String shopId, DateTime date) =>
      getRevenueForRange(shopId, date, date);

  @override
  Future<double> getRevenueForRange(String shopId, DateTime from, DateTime to) async {
    final json = await _client.get('/shops/$shopId/sales/revenue', query: {
      'start': _dateOnly(from),
      'end': _dateOnly(to),
    });
    return (json['revenue'] as num).toDouble();
  }

  Future<List<RevenuePoint>> _series(
      String shopId, DateTime from, DateTime to, String groupBy) async {
    final json = await _client.get('/shops/$shopId/sales/series', query: {
      'start': _dateOnly(from),
      'end': _dateOnly(to),
      'group_by': groupBy,
    });
    return (json as List)
        .map((p) => RevenuePoint(
              (p as Map<String, dynamic>)['bucket_label'] as String,
              (p['revenue'] as num).toDouble(),
            ))
        .toList();
  }

  @override
  Future<List<RevenuePoint>> getDailySeries(String shopId, DateTime from, DateTime to) =>
      _series(shopId, from, to, 'day');

  @override
  Future<List<RevenuePoint>> getWeeklySeries(String shopId, DateTime from, DateTime to) =>
      _series(shopId, from, to, 'week');

  @override
  Future<List<RevenuePoint>> getMonthlySeries(String shopId, DateTime from, DateTime to) =>
      _series(shopId, from, to, 'month');

  @override
  Future<List<MapEntry<String, double>>> getTopProductsByQuantity(
      String shopId, DateTime from, DateTime to,
      {int limit = 5}) async {
    final json = await _client.get('/shops/$shopId/sales/top-products', query: {
      'start': _dateOnly(from),
      'end': _dateOnly(to),
      'limit': limit,
    });
    return (json as List)
        .map((p) => MapEntry(
              (p as Map<String, dynamic>)['product_name'] as String,
              (p['quantity'] as num).toDouble(),
            ))
        .toList();
  }
}
