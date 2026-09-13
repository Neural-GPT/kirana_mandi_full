import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product_model.dart';
import '../../data/models/region_model.dart';
import '../../data/models/service_model.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/call_log_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/service_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/product_tile.dart';
import 'cart_controller.dart';
import 'cart_screen.dart';

class ShopProfileScreen extends StatefulWidget {
  final String shopId;
  const ShopProfileScreen({super.key, required this.shopId});

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

/// Renders as an "Add" button, or a quantity stepper once the product is
/// already in the cart -- passed as ProductTile's `trailing` widget so
/// no change to ProductTile itself was needed.
class _AddToCartControl extends StatelessWidget {
  final ShopModel shop;
  final ProductModel product;
  const _AddToCartControl({required this.shop, required this.product});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartController>(
      builder: (context, cart, _) {
        final qty = cart.quantityFor(product.id);
        if (qty == 0) {
          return OutlinedButton(
            onPressed: () => cart.addItem(
              shopId: shop.id,
              shopName: shop.name,
              productId: product.id,
              productName: product.name,
              unit: product.unit,
              unitPrice: product.price,
            ),
            child: const Text('Add'),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: () => cart.setQuantity(product.id, qty - 1),
            ),
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.w600)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => cart.setQuantity(product.id, qty + 1),
            ),
          ],
        );
      },
    );
  }
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  ShopModel? _shop;
  RegionModel? _region;
  List<ServiceModel> _allServices = [];
  List<String> _shopServiceIds = [];
  List<ProductModel> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shopRepo = context.read<ShopRepository>();
    final regionRepo = context.read<RegionRepository>();
    final serviceRepo = context.read<ServiceRepository>();
    final productRepo = context.read<ProductRepository>();

    final shop = await shopRepo.getShopById(widget.shopId);
    if (shop == null) {
      setState(() => _loading = false);
      return;
    }
    final results = await Future.wait([
      regionRepo.getRegionById(shop.regionId),
      serviceRepo.getAllServices(),
      serviceRepo.getServiceIdsForShop(shop.id),
      productRepo.getProductsByShop(shop.id, availableOnly: true),
    ]);

    if (!mounted) return;
    setState(() {
      _shop = shop;
      _region = results[0] as RegionModel?;
      _allServices = results[1] as List<ServiceModel>;
      _shopServiceIds = results[2] as List<String>;
      _products = results[3] as List<ProductModel>;
      _loading = false;
    });
  }

  Future<void> _callShop(String phone) async {
    // Best-effort call log so the shopkeeper can see call activity on
    // their Calls page. Logged before launching the dialer since we can't
    // reliably know if the user actually completed the call afterwards.
    try {
      await context.read<CallLogRepository>().logCall(shopId: widget.shopId);
    } catch (_) {
      // Non-critical -- don't block the call attempt if logging fails.
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMaps(ShopModel shop) async {
    final Uri uri;
    if (shop.hasLocation) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${shop.latitude},${shop.longitude}');
    } else {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(shop.name)}');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final shop = _shop;
    if (shop == null) {
      return const Scaffold(
        body: EmptyState(icon: Icons.error_outline, title: 'Shop not found'),
      );
    }

    final shopServices = _allServices
        .where((s) => _shopServiceIds.contains(s.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(shop.name)),
      floatingActionButton: Consumer<CartController>(
        builder: (context, cart, _) => cart.itemCount == 0
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const CartScreen())),
                icon: const Icon(Icons.shopping_cart),
                label: Text('Cart (${cart.itemCount})'),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      if (!shop.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Temporarily unavailable',
                              style: TextStyle(
                                  color: AppColors.danger, fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${_region?.name ?? ''} · Owner: ${shop.ownerName}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  if (shop.description != null && shop.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(shop.description!),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callShop(shop.phone),
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: const Text('Call Shop'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openMaps(shop),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('View on Maps'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        shop.homeDeliveryAvailable
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 18,
                        color: shop.homeDeliveryAvailable
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(shop.homeDeliveryAvailable
                          ? 'Home delivery available'
                          : 'No home delivery'),
                    ],
                  ),
                  if (shop.homeDeliveryAvailable) ...[
                    const SizedBox(height: 6),
                    if (shop.deliveryRadiusKm != null)
                      Text(
                          'Delivery radius: ${Formatters.km(shop.deliveryRadiusKm!)}'),
                    if (shop.deliveryFee != null)
                      Text(
                          'Delivery fee: ${Formatters.rupees(shop.deliveryFee!)}'),
                  ],
                  if (shopServices.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Services',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shopServices
                          .map((s) => Chip(label: Text(s.name)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_products.isEmpty)
            const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products listed yet',
            )
          else
            ..._products.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ProductTile(
                    product: p,
                    trailing: p.isAvailable
                        ? _AddToCartControl(shop: shop, product: p)
                        : null,
                  ),
                )),
        ],
      ),
    );
  }
}
