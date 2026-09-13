import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/settings_screen.dart';
import '../shared/widgets/offline_banner.dart';
import 'analytics_screen.dart';
import 'calls_screen.dart';
import 'daily_sales_screen.dart';
import 'services_delivery_screen.dart';
import 'shop_setup_screen.dart';
import 'shopkeeper_orders_screen.dart';

class ShopkeeperDashboardScreen extends StatefulWidget {
  const ShopkeeperDashboardScreen({super.key});

  @override
  State<ShopkeeperDashboardScreen> createState() =>
      _ShopkeeperDashboardScreenState();
}

class _ShopkeeperDashboardScreenState
    extends State<ShopkeeperDashboardScreen> {
  ShopModel? _shop;
  int _productCount = 0;
  double _weeklyRevenue = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthController>().currentUser!;
    final shop = await context.read<ShopRepository>().getShopByOwnerId(auth.id);
    int productCount = 0;
    double weeklyRevenue = 0;
    if (shop != null) {
      final products =
          await context.read<ProductRepository>().getProductsByShop(shop.id);
      productCount = products.length;
      final now = DateTime.now();
      weeklyRevenue = await context.read<SalesRepository>().getRevenueForRange(
            shop.id,
            now.subtract(const Duration(days: 6)),
            now,
          );
    }
    if (!mounted) return;
    setState(() {
      _shop = shop;
      _productCount = productCount;
      _weeklyRevenue = weeklyRevenue;
      _loading = false;
    });
  }

  Future<void> _toggleAvailability(bool value) async {
    final auth = context.read<AuthController>().currentUser!;
    await context.read<ShopRepository>().setShopAvailability(
          _shop!.id,
          value,
          requestingUserId: auth.id,
        );
    _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.shopStatusApproved:
        return AppColors.success;
      case AppConstants.shopStatusRejected:
        return AppColors.danger;
      default:
        return AppColors.pending;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case AppConstants.shopStatusApproved:
        return 'Approved & Live';
      case AppConstants.shopStatusRejected:
        return 'Rejected';
      default:
        return 'Pending Approval';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final shop = _shop;
    if (shop == null) {
      return const Scaffold(body: Center(child: Text('Shop not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: AppColors.primary.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Revenue',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                              Text(Formatters.rupees(_weeklyRevenue),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: const Text('Filter: Weekly',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(shop.name,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(shop.status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(shop.status),
                                style: TextStyle(
                                    color: _statusColor(shop.status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('$_productCount products listed',
                            style: const TextStyle(color: AppColors.textSecondary)),
                        if (shop.status == AppConstants.shopStatusPending) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Your shop is awaiting admin approval and is not yet visible to customers.',
                            style: TextStyle(color: AppColors.pending, fontSize: 12),
                          ),
                        ],
                        const Divider(height: 24),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Shop is open / available'),
                          subtitle: const Text(
                              'Turn off to temporarily hide your shop from customers'),
                          value: shop.isAvailable,
                          onChanged: _toggleAvailability,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _DashboardTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Manage Products',
                  subtitle: 'Add, edit, or remove items from your catalog',
                  onTap: () => Navigator.pushNamed(context, '/shopkeeper/products',
                      arguments: shop),
                ),
                const SizedBox(height: 10),
                _DashboardTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders',
                  subtitle: 'Accept/reject orders and update delivery status',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ShopkeeperOrdersScreen(shopId: shop.id)),
                  ),
                ),
                const SizedBox(height: 10),
                _DashboardTile(
                  icon: Icons.storefront_outlined,
                  title: 'Edit Shop Profile',
                  subtitle: 'Update name, description, category, and location',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ShopSetupScreen(existingShop: shop)),
                    );
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                _DashboardTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'Services & Delivery',
                  subtitle: 'Configure delivery radius, fee, and services offered',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ServicesDeliveryScreen(shop: shop)),
                    );
                    _load();
                  },
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4, left: 4),
                  child: Text('Sales & Insights',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 8),
                _DashboardTile(
                  icon: Icons.point_of_sale_outlined,
                  title: "Today's Sales",
                  subtitle: "Log what sold today and see the day's revenue",
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DailySalesScreen(shopId: shop.id)),
                    );
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                _DashboardTile(
                  icon: Icons.bar_chart_outlined,
                  title: 'Analytics',
                  subtitle: 'Revenue trends, daily/weekly/monthly, top sellers',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AnalyticsScreen(shopId: shop.id)),
                  ),
                ),
                const SizedBox(height: 10),
                _DashboardTile(
                  icon: Icons.call_outlined,
                  title: 'Calls',
                  subtitle: 'See who called your shop and when',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CallsScreen(shopId: shop.id)),
                  ),
                ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                foregroundColor: AppColors.primary,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
