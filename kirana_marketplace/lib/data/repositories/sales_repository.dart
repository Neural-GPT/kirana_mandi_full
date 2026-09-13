import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../models/sale_item_model.dart';
import 'sync_queue_repository.dart';

/// One line the shopkeeper types in on the Daily Sales screen: a product
/// name/quantity/price. Kept separate from [SaleItemModel] so the UI layer
/// doesn't need to invent ids/timestamps/shopId before the user hits save.
class SaleEntryInput {
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  SaleEntryInput({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });
}

/// A (bucketLabel, totalRevenue) pair for chart plotting -- bucketLabel is
/// a day ('2026-09-10'), an ISO year-week ('2026-W37'), or a month
/// ('2026-09') depending on which series method was called.
class RevenuePoint {
  final String bucketLabel;
  final double revenue;
  RevenuePoint(this.bucketLabel, this.revenue);
}

abstract class SalesRepository {
  Future<void> recordDailySales({
    required String shopId,
    required DateTime date,
    required List<SaleEntryInput> entries,
  });

  Future<List<SaleItemModel>> getSaleItemsForDate(String shopId, DateTime date);
  Future<double> getRevenueForDate(String shopId, DateTime date);
  Future<double> getRevenueForRange(String shopId, DateTime from, DateTime to);

  Future<List<RevenuePoint>> getDailySeries(String shopId, DateTime from, DateTime to);
  Future<List<RevenuePoint>> getWeeklySeries(String shopId, DateTime from, DateTime to);
  Future<List<RevenuePoint>> getMonthlySeries(String shopId, DateTime from, DateTime to);

  /// Best-selling products by total quantity within a date range, for the
  /// analytics breakdown list.
  Future<List<MapEntry<String, double>>> getTopProductsByQuantity(
      String shopId, DateTime from, DateTime to, {int limit = 5});
}

class SqliteSalesRepository implements SalesRepository {
  final _uuid = const Uuid();
  final SyncQueueRepository _syncQueue;
  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  SqliteSalesRepository({SyncQueueRepository? syncQueue})
      : _syncQueue = syncQueue ?? SyncQueueRepository();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  String _fmt(DateTime d) => _dateFmt.format(d);

  @override
  Future<void> recordDailySales({
    required String shopId,
    required DateTime date,
    required List<SaleEntryInput> entries,
  }) async {
    if (entries.isEmpty) return;
    final db = await _db;
    final dateStr = _fmt(date);
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final entry in entries) {
      final id = _uuid.v4();
      batch.insert('sale_items', {
        'id': id,
        'shop_id': shopId,
        'product_id': entry.productId,
        'product_name': entry.productName,
        'quantity': entry.quantity,
        'unit_price': entry.unitPrice,
        'sale_date': dateStr,
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
    await _syncQueue.enqueue(
      entityType: 'sale_items_batch',
      entityId: '$shopId:$dateStr:${DateTime.now().millisecondsSinceEpoch}',
      operation: 'create',
    );
  }

  @override
  Future<List<SaleItemModel>> getSaleItemsForDate(
      String shopId, DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      'sale_items',
      where: 'shop_id = ? AND sale_date = ?',
      whereArgs: [shopId, _fmt(date)],
      orderBy: 'created_at DESC',
    );
    return rows.map(SaleItemModel.fromMap).toList();
  }

  @override
  Future<double> getRevenueForDate(String shopId, DateTime date) async {
    return getRevenueForRange(shopId, date, date);
  }

  @override
  Future<double> getRevenueForRange(
      String shopId, DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity * unit_price), 0) as total
      FROM sale_items
      WHERE shop_id = ? AND sale_date BETWEEN ? AND ?
    ''', [shopId, _fmt(from), _fmt(to)]);
    final value = rows.first['total'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  Future<List<RevenuePoint>> _seriesByGroupExpr(
    String shopId,
    DateTime from,
    DateTime to,
    String groupExpr,
  ) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT $groupExpr as bucket, SUM(quantity * unit_price) as total
      FROM sale_items
      WHERE shop_id = ? AND sale_date BETWEEN ? AND ?
      GROUP BY bucket
      ORDER BY bucket ASC
    ''', [shopId, _fmt(from), _fmt(to)]);
    return rows
        .map((r) => RevenuePoint(
              r['bucket'] as String,
              (r['total'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();
  }

  @override
  Future<List<RevenuePoint>> getDailySeries(
          String shopId, DateTime from, DateTime to) =>
      _seriesByGroupExpr(shopId, from, to, 'sale_date');

  @override
  Future<List<RevenuePoint>> getWeeklySeries(
          String shopId, DateTime from, DateTime to) =>
      _seriesByGroupExpr(
          shopId, from, to, "strftime('%Y-W%W', sale_date)");

  @override
  Future<List<RevenuePoint>> getMonthlySeries(
          String shopId, DateTime from, DateTime to) =>
      _seriesByGroupExpr(shopId, from, to, "strftime('%Y-%m', sale_date)");

  @override
  Future<List<MapEntry<String, double>>> getTopProductsByQuantity(
      String shopId, DateTime from, DateTime to,
      {int limit = 5}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT product_name, SUM(quantity) as qty
      FROM sale_items
      WHERE shop_id = ? AND sale_date BETWEEN ? AND ?
      GROUP BY product_name
      ORDER BY qty DESC
      LIMIT ?
    ''', [shopId, _fmt(from), _fmt(to), limit]);
    return rows
        .map((r) => MapEntry(
              r['product_name'] as String,
              (r['qty'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();
  }
}
