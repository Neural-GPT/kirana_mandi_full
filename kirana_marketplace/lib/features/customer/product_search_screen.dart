import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/icon_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shop_theme_controller.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../shared/widgets/empty_state.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _controller = TextEditingController();
  List<ProductSearchResult>? _results;
  bool _searching = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _searching = true);

    final tenant = context.read<ShopThemeController>();
    List<ProductSearchResult> results;
    if (tenant.isLockedToShop) {
      // Single-shop (white-label) mode: never let a global cross-shop
      // search leak other tenants' products into this build -- search
      // only within the one shop this install is locked to.
      final shopId = tenant.shopId!;
      final shop = await context.read<ShopRepository>().getShopById(shopId);
      final products = await context
          .read<ProductRepository>()
          .getProductsByShop(shopId, availableOnly: true);
      final q = query.trim().toLowerCase();
      results = shop == null
          ? []
          : products
              .where((p) => p.name.toLowerCase().contains(q))
              .map((p) => ProductSearchResult(product: p, shop: shop))
              .toList();
    } else {
      results =
          await context.read<ProductRepository>().searchProductsByName(query.trim());
    }

    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search products e.g. milk, rice, soap',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            // IMPORTANT: the app-wide InputDecorationTheme (see app_theme.dart)
            // sets `filled: true, fillColor: Colors.white` for every text
            // field so form fields look consistent. Left unset here, that
            // theme leaks into this field too -- white fill behind white
            // text is why what you typed was invisible. Explicitly turning
            // fill off restores the transparent field the AppBar look needs.
            filled: false,
            fillColor: Colors.transparent,
          ),
          onSubmitted: _search,
          onChanged: (v) {
            if (v.trim().isEmpty) setState(() => _results = null);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : _results == null
              ? const EmptyState(
                  icon: Icons.search,
                  title: 'Search for a product',
                  subtitle:
                      'Find which nearby shops sell what you need.',
                )
              : _results!.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'No matching products found',
                      subtitle: 'Try a different search term.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final r = _results![index];
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pushNamed(
                                context, '/customer/shop',
                                arguments: r.shop.id),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                        IconRegistry.iconFor(r.product.iconId),
                                        color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(r.product.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text('at ${r.shop.name}',
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textSecondary,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text(Formatters.rupees(r.product.price),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
