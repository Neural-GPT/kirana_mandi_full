import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/region_model.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/shop_card.dart';

class ShopListScreen extends StatefulWidget {
  final String regionId;
  const ShopListScreen({super.key, required this.regionId});

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  late Future<List<ShopModel>> _shopsFuture;
  RegionModel? _region;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _shopsFuture =
        context.read<ShopRepository>().getShopsByRegion(widget.regionId);
    _loadRegion();
  }

  Future<void> _loadRegion() async {
    final region =
        await context.read<RegionRepository>().getRegionById(widget.regionId);
    if (mounted) setState(() => _region = region);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_region?.name ?? 'Shops')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter shops by name',
              ),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ShopModel>>(
              future: _shopsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var shops = snapshot.data!;
                if (_filter.isNotEmpty) {
                  shops = shops
                      .where((s) => s.name.toLowerCase().contains(_filter))
                      .toList();
                }
                if (shops.isEmpty) {
                  return const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No shops found here yet',
                    subtitle: 'Try another area or check back later.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: shops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return ShopCard(
                      shop: shop,
                      regionName: _region?.name ?? '',
                      onTap: () => Navigator.pushNamed(
                          context, '/customer/shop',
                          arguments: shop.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
