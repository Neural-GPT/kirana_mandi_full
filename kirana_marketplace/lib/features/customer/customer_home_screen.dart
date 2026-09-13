import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/region_model.dart';
import '../../data/repositories/region_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/settings_screen.dart';
import '../shared/widgets/empty_state.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late Future<List<RegionModel>> _regionsFuture;

  @override
  void initState() {
    super.initState();
    _regionsFuture = context.read<RegionRepository>().getAllRegions();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name?.isNotEmpty == true
            ? 'Hi, ${user!.name}'
            : AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Account & Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _regionsFuture = context.read<RegionRepository>().getAllRegions();
          });
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pushNamed(context, '/customer/search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: AppColors.textSecondary),
                      SizedBox(width: 10),
                      Text('Search for milk, rice, soap...',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Browse by Area',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            FutureBuilder<List<RegionModel>>(
              future: _regionsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final regions = snapshot.data!;
                if (regions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.map_outlined,
                    title: 'No areas available yet',
                    subtitle: 'Please check back soon.',
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                  ),
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return _RegionTile(region: region);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  final RegionModel region;
  const _RegionTile({required this.region});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/customer/shops',
            arguments: region.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  region.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
