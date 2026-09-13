import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/region_model.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../shared/widgets/empty_state.dart';

class ShopApprovalScreen extends StatefulWidget {
  const ShopApprovalScreen({super.key});

  @override
  State<ShopApprovalScreen> createState() => _ShopApprovalScreenState();
}

class _ShopApprovalScreenState extends State<ShopApprovalScreen> {
  List<ShopModel> _pendingShops = [];
  Map<String, String> _regionNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final shops = await context
        .read<ShopRepository>()
        .getShopsByStatus(AppConstants.shopStatusPending);
    final regions = await context.read<RegionRepository>().getAllRegions(activeOnly: false);
    if (!mounted) return;
    setState(() {
      _pendingShops = shops;
      _regionNames = {for (final r in regions) r.id: r.name};
      _loading = false;
    });
  }

  Future<void> _decide(ShopModel shop, String status) async {
    await context.read<ShopRepository>().setShopStatus(shop.id, status);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop Approvals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingShops.isEmpty
              ? const EmptyState(
                  icon: Icons.task_alt,
                  title: 'No shops waiting for review',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingShops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final shop = _pendingShops[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shop.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(
                                '${_regionNames[shop.regionId] ?? 'Unknown area'} · Owner: ${shop.ownerName}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Phone: ${shop.phone}',
                                style: const TextStyle(fontSize: 12)),
                            if (shop.description != null &&
                                shop.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(shop.description!),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _decide(
                                        shop, AppConstants.shopStatusRejected),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.danger,
                                        side: const BorderSide(
                                            color: AppColors.danger)),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _decide(
                                        shop, AppConstants.shopStatusApproved),
                                    child: const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
