import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/sales_repository.dart';
import '../shared/widgets/empty_state.dart';

enum _Filter { daily, weekly, monthly }

extension on _Filter {
  String get label {
    switch (this) {
      case _Filter.daily:
        return 'Daily';
      case _Filter.weekly:
        return 'Weekly';
      case _Filter.monthly:
        return 'Monthly';
    }
  }
}

/// Revenue graphs and a top-products breakdown, filterable by
/// Daily/Weekly/Monthly. Backed by [SalesRepository] aggregation queries
/// over the shopkeeper's `sale_items` entries (see DailySalesScreen).
class AnalyticsScreen extends StatefulWidget {
  final String shopId;
  const AnalyticsScreen({super.key, required this.shopId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Filter _filter = _Filter.weekly;
  bool _loading = true;
  List<RevenuePoint> _points = [];
  double _totalRevenue = 0;
  List<MapEntry<String, double>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({DateTime from, DateTime to}) _rangeFor(_Filter filter) {
    final now = DateTime.now();
    switch (filter) {
      case _Filter.daily:
        return (from: now.subtract(const Duration(days: 13)), to: now);
      case _Filter.weekly:
        return (from: now.subtract(const Duration(days: 7 * 11)), to: now);
      case _Filter.monthly:
        return (from: DateTime(now.year - 1, now.month, now.day), to: now);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<SalesRepository>();
    final range = _rangeFor(_filter);

    List<RevenuePoint> points;
    switch (_filter) {
      case _Filter.daily:
        points = await repo.getDailySeries(widget.shopId, range.from, range.to);
        break;
      case _Filter.weekly:
        points = await repo.getWeeklySeries(widget.shopId, range.from, range.to);
        break;
      case _Filter.monthly:
        points =
            await repo.getMonthlySeries(widget.shopId, range.from, range.to);
        break;
    }

    final total = await repo.getRevenueForRange(widget.shopId, range.from, range.to);
    final top = await repo.getTopProductsByQuantity(
        widget.shopId, range.from, range.to);

    if (!mounted) return;
    setState(() {
      _points = points;
      _totalRevenue = total;
      _topProducts = top;
      _loading = false;
    });
  }

  void _onFilterChanged(_Filter filter) {
    setState(() => _filter = filter);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Revenue',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          Text(
                            Formatters.rupees(_totalRevenue),
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    _FilterDropdown(value: _filter, onChanged: _onFilterChanged),
                  ],
                ),
                const SizedBox(height: 20),
                if (_points.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: EmptyState(
                      icon: Icons.show_chart,
                      title: 'No sales recorded for this period',
                      subtitle: 'Log sales from "Today\'s Sales" to see trends here.',
                    ),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: _RevenueChart(points: _points),
                  ),
                const SizedBox(height: 28),
                if (_topProducts.isNotEmpty) ...[
                  const Text('Top-selling items',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  ..._topProducts.map((entry) => Card(
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.trending_up,
                              color: AppColors.primary),
                          title: Text(entry.key),
                          trailing: Text('${entry.value.toStringAsFixed(
                              entry.value == entry.value.roundToDouble() ? 0 : 1)} sold'),
                        ),
                      )),
                ],
              ],
            ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final _Filter value;
  final ValueChanged<_Filter> onChanged;
  const _FilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Filter>(
          value: value,
          icon: const Icon(Icons.expand_more, size: 18),
          items: _Filter.values
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text('Filter: ${f.label}',
                        style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (f) {
            if (f != null) onChanged(f);
          },
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<RevenuePoint> points;
  const _RevenueChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxY = points.map((p) => p.revenue).fold<double>(0, (a, b) => a > b ? a : b);
    final safeMaxY = maxY <= 0 ? 10.0 : maxY * 1.2;

    return BarChart(
      BarChartData(
        maxY: safeMaxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              Formatters.rupees(rod.toY),
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                // Trim labels to keep the axis readable regardless of
                // whether it's a date, an ISO week, or a month bucket.
                final label = points[index].bucketLabel;
                final short = label.length > 7 ? label.substring(5) : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].revenue,
                  color: AppColors.primary,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
