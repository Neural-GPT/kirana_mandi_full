import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/region_model.dart';
import '../../data/models/shop_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/settings_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/offline_banner.dart';
import 'category_management_screen.dart';
import 'icon_management_screen.dart';
import 'manage_admins_screen.dart';
import 'region_management_screen.dart';
import 'service_management_screen.dart';
import 'shop_approval_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = context.read<ShopRepository>().getPlatformStats();
  }

  void _refresh() {
    setState(() {
      _statsFuture = context.read<ShopRepository>().getPlatformStats();
    });
  }

  /// Generic "detail popup" used by every stat card: opens a modal sheet
  /// showing a title and a loading -> list/empty view built from
  /// [itemsFuture] + [itemBuilder].
  void _showDetailSheet<T>({
    required String title,
    required Future<List<T>> itemsFuture,
    required Widget Function(T item) itemBuilder,
    required IconData emptyIcon,
    required String emptyLabel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<T>>(
                    future: itemsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Could not load this right now.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return EmptyState(icon: emptyIcon, title: emptyLabel);
                      }
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => itemBuilder(items[index]),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _shopStatusColor(String status) {
    switch (status) {
      case AppConstants.shopStatusApproved:
        return AppColors.success;
      case AppConstants.shopStatusRejected:
        return AppColors.danger;
      default:
        return AppColors.pending;
    }
  }

  Widget _shopTile(ShopModel shop) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _shopStatusColor(shop.status).withOpacity(0.12),
          foregroundColor: _shopStatusColor(shop.status),
          child: const Icon(Icons.storefront, size: 18),
        ),
        title: Text(shop.name),
        subtitle: Text('Owner: ${shop.ownerName} · ${shop.phone}'),
        trailing: Text(
          shop.status[0].toUpperCase() + shop.status.substring(1),
          style: TextStyle(
              color: _shopStatusColor(shop.status),
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _openTotalShops() {
    _showDetailSheet<ShopModel>(
      title: 'All Shops',
      itemsFuture: context.read<ShopRepository>().getAllShops(),
      itemBuilder: _shopTile,
      emptyIcon: Icons.storefront_outlined,
      emptyLabel: 'No shops yet',
    );
  }

  void _openPendingShops() {
    _showDetailSheet<ShopModel>(
      title: 'Pending Approval',
      itemsFuture: context
          .read<ShopRepository>()
          .getShopsByStatus(AppConstants.shopStatusPending),
      itemBuilder: _shopTile,
      emptyIcon: Icons.task_alt,
      emptyLabel: 'Nothing pending',
    );
  }

  void _openApprovedShops() {
    _showDetailSheet<ShopModel>(
      title: 'Approved Shops',
      itemsFuture: context
          .read<ShopRepository>()
          .getShopsByStatus(AppConstants.shopStatusApproved),
      itemBuilder: _shopTile,
      emptyIcon: Icons.storefront_outlined,
      emptyLabel: 'No approved shops yet',
    );
  }

  void _openTotalProducts() {
    _showDetailSheet(
      title: 'All Products',
      itemsFuture: context
          .read<ProductRepository>()
          .getAllProductsAcrossShops(limit: 200),
      itemBuilder: (result) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.inventory_2_outlined, size: 18),
          ),
          title: Text(result.product.name),
          subtitle: Text('at ${result.shop.name}'),
          trailing: Text(Formatters.rupees(result.product.price),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      emptyIcon: Icons.inventory_2_outlined,
      emptyLabel: 'No products listed yet',
    );
  }

  void _openRegions() {
    _showDetailSheet<RegionModel>(
      title: 'Active Regions',
      itemsFuture: context.read<RegionRepository>().getAllRegions(),
      itemBuilder: (region) => Card(
        child: ListTile(
          leading: const Icon(Icons.location_on_outlined,
              color: AppColors.primary),
          title: Text(region.name),
        ),
      ),
      emptyIcon: Icons.map_outlined,
      emptyLabel: 'No regions added yet',
    );
  }

  void _openCustomers() {
    _showDetailSheet<UserModel>(
      title: 'Customers',
      itemsFuture:
          context.read<AuthRepository>().getUsersByRole(AppConstants.roleCustomer),
      itemBuilder: (user) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(user.name?.isNotEmpty == true ? user.name! : user.phone),
          subtitle: Text(user.phone),
        ),
      ),
      emptyIcon: Icons.people_outline,
      emptyLabel:
          'No customer accounts yet (customers can browse without logging in)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthController>().currentUser;
    final isSuperAdmin = currentUser?.role == AppConstants.roleSuperAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FutureBuilder<Map<String, int>>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      final stats = snapshot.data ??
                          const {
                            'totalShops': 0,
                            'pendingShops': 0,
                            'approvedShops': 0,
                            'totalProducts': 0,
                            'totalRegions': 0,
                            'totalCustomers': 0,
                          };
                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.7,
                        children: [
                          _StatCard(
                              label: 'Total Shops',
                              value: stats['totalShops']!,
                              color: AppColors.primary,
                              onTap: _openTotalShops),
                          _StatCard(
                              label: 'Pending Approval',
                              value: stats['pendingShops']!,
                              color: AppColors.warning,
                              onTap: _openPendingShops),
                          _StatCard(
                              label: 'Approved Shops',
                              value: stats['approvedShops']!,
                              color: AppColors.success,
                              onTap: _openApprovedShops),
                          _StatCard(
                              label: 'Total Products',
                              value: stats['totalProducts']!,
                              color: AppColors.accent,
                              onTap: _openTotalProducts),
                          _StatCard(
                              label: 'Active Regions',
                              value: stats['totalRegions']!,
                              color: AppColors.primaryDark,
                              onTap: _openRegions),
                          _StatCard(
                              label: 'Customers',
                              value: stats['totalCustomers']!,
                              color: AppColors.pending,
                              onTap: _openCustomers),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _AdminTile(
                    icon: Icons.fact_check_outlined,
                    title: 'Shop Approvals',
                    subtitle: 'Review and approve or reject new shops',
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ShopApprovalScreen()));
                      _refresh();
                    },
                  ),
                  const SizedBox(height: 10),
                  _AdminTile(
                    icon: Icons.map_outlined,
                    title: 'Manage Regions',
                    subtitle: 'Add, rename, or disable regions/areas',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegionManagementScreen())),
                  ),
                  const SizedBox(height: 10),
                  _AdminTile(
                    icon: Icons.category_outlined,
                    title: 'Manage Categories',
                    subtitle: 'Shop categories and product categories',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CategoryManagementScreen())),
                  ),
                  const SizedBox(height: 10),
                  _AdminTile(
                    icon: Icons.emoji_symbols_outlined,
                    title: 'Manage Icon Library',
                    subtitle: 'Enable/disable built-in product icons',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const IconManagementScreen())),
                  ),
                  const SizedBox(height: 10),
                  _AdminTile(
                    icon: Icons.miscellaneous_services_outlined,
                    title: 'Manage Services',
                    subtitle: 'Service types shopkeepers can offer',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ServiceManagementScreen())),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(height: 10),
                    _AdminTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Manage Admins',
                      subtitle: 'Add or remove admin and super admin accounts',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ManageAdminsScreen())),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$value',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({
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
