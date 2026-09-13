import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/run_guarded.dart';
import '../../data/models/product_model.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../shared/widgets/empty_state.dart';

/// Lets a shopkeeper record what sold today (picking from their catalog,
/// or typing a free-text item + quantity), and shows the running total
/// revenue for the day as they add lines.
class DailySalesScreen extends StatefulWidget {
  final String shopId;
  const DailySalesScreen({super.key, required this.shopId});

  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  List<ProductModel> _catalog = [];
  List<SaleItemModel> _todaysSales = [];
  final List<_DraftLine> _draftLines = [];
  bool _loading = true;
  bool _saving = false;

  final _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final catalog = await context
        .read<ProductRepository>()
        .getProductsByShop(widget.shopId);
    final sales = await context
        .read<SalesRepository>()
        .getSaleItemsForDate(widget.shopId, _today);
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _todaysSales = sales;
      _loading = false;
    });
  }

  double get _alreadyRecordedRevenue =>
      _todaysSales.fold(0.0, (sum, item) => sum + item.revenue);

  double get _draftRevenue =>
      _draftLines.fold(0.0, (sum, line) => sum + line.revenue);

  void _addDraftLine() {
    setState(() => _draftLines.add(_DraftLine()));
  }

  void _removeDraftLine(_DraftLine line) {
    setState(() => _draftLines.remove(line));
  }

  Future<void> _save() async {
    final validLines =
        _draftLines.where((l) => l.isValid).map((l) => l.toEntry()).toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one item with a quantity and price')));
      return;
    }

    setState(() => _saving = true);
    final result = await runGuarded<bool>(
      context,
      () async {
        await context.read<SalesRepository>().recordDailySales(
              shopId: widget.shopId,
              date: _today,
              entries: validLines,
            );
        return true;
      },
      successMessage: 'Sales recorded',
    );
    setState(() => _saving = false);
    if (result != null) {
      _draftLines.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalToday = _alreadyRecordedRevenue + _draftRevenue;

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Sales")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: AppColors.primary.withOpacity(0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Today's revenue",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          Formatters.rupees(totalToday),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_todaysSales.isNotEmpty) ...[
                  const Text('Already recorded today',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ..._todaysSales.map((s) => Card(
                        child: ListTile(
                          dense: true,
                          title: Text(s.productName),
                          subtitle: Text('${s.quantity} × ${Formatters.rupees(s.unitPrice)}'),
                          trailing: Text(Formatters.rupees(s.revenue),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      )),
                  const SizedBox(height: 20),
                ],
                const Text('Add items sold',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (_draftLines.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No items added yet',
                    subtitle: 'Tap "Add item" below to start entering sales.',
                  )
                else
                  ..._draftLines.map((line) => _DraftLineCard(
                        line: line,
                        catalog: _catalog,
                        onChanged: () => setState(() {}),
                        onRemove: () => _removeDraftLine(line),
                      )),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _addDraftLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Sales'),
                ),
              ],
            ),
    );
  }
}

class _DraftLine {
  ProductModel? selectedProduct;
  final nameController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();

  bool get isValid {
    final qty = double.tryParse(qtyController.text.trim());
    final price = double.tryParse(priceController.text.trim());
    return nameController.text.trim().isNotEmpty &&
        qty != null &&
        qty > 0 &&
        price != null &&
        price >= 0;
  }

  double get revenue {
    final qty = double.tryParse(qtyController.text.trim()) ?? 0;
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    return qty * price;
  }

  SaleEntryInput toEntry() => SaleEntryInput(
        productId: selectedProduct?.id,
        productName: nameController.text.trim(),
        quantity: double.parse(qtyController.text.trim()),
        unitPrice: double.parse(priceController.text.trim()),
      );
}

class _DraftLineCard extends StatelessWidget {
  final _DraftLine line;
  final List<ProductModel> catalog;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _DraftLineCard({
    required this.line,
    required this.catalog,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ProductModel>(
                    value: line.selectedProduct,
                    decoration: const InputDecoration(
                      labelText: 'Pick from catalog (optional)',
                      isDense: true,
                    ),
                    items: catalog
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (product) {
                      line.selectedProduct = product;
                      if (product != null) {
                        line.nameController.text = product.name;
                        line.priceController.text = product.price.toString();
                      }
                      onChanged();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.danger),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: line.nameController,
              decoration: const InputDecoration(
                  labelText: 'Item name', isDense: true),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.qtyController,
                    decoration: const InputDecoration(
                        labelText: 'Quantity', isDense: true),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: line.priceController,
                    decoration: const InputDecoration(
                        labelText: 'Price/unit (₹)', isDense: true),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text('= ${Formatters.rupees(line.revenue)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
