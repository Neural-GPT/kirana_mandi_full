import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shop_theme_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/run_guarded.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/repositories/shop_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/widgets/empty_state.dart';
import 'cart_controller.dart';

/// Cart grouped by shop -- a customer can add items from several
/// different shops, and each shop group checks out (and is called
/// about) independently, since only that shop's items travel together.
/// In single-shop (white-label) mode there's only ever one group -- see
/// CartController.restrictToShop.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Future<void> _callThenOrder(CartShopGroup group) async {
    // The shop's phone isn't stored on the cart item, so look it up once
    // at checkout time -- also doubles as a cheap "does this shop still
    // exist / is it still available" check right before ordering.
    final shop = await context.read<ShopRepository>().getShopById(group.shopId);
    if (!mounted) return;
    if (shop == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This shop is no longer available.')));
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm with the shop first'),
        content: Text(
          "Before placing this order, it's a good idea to call "
          '${shop.name} to confirm they have everything in stock. '
          "Once you've placed it, the shopkeeper still needs to accept "
          'it in the app before it\'s confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri(scheme: 'tel', path: shop.phone);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: const Text('Call Shop'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Place Order'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final auth = context.read<AuthController>().currentUser!;
    final placed = await runGuarded(
      context,
      () => context.read<CartController>().checkout(
            customerId: auth.id,
            customerName: auth.name ?? 'Customer',
            customerPhone: auth.phone,
            groups: [group],
            shopPhoneById: {group.shopId: shop.phone},
          ),
      successMessage: 'Order placed! ${shop.name} will confirm it shortly.',
    );
    if (placed == null || !mounted) return;

    // Single-shop (white-label) mode: order details (items, quantities,
    // customer contact) travel with the order itself, and the
    // shopkeeper's number is dialed straight away on confirmation so the
    // customer doesn't have to look it up separately -- see
    // ARCHITECTURAL GOALS > Phase 3 "Direct Cart & Single-Shop Checkout".
    final tenant = context.read<ShopThemeController>();
    if (tenant.isLockedToShop) {
      final uri = Uri(scheme: 'tel', path: shop.phone);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final groups = cart.groupedByShop;

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: cart.loading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  subtitle: 'Add items from a shop to see them here.',
                )
              : RefreshIndicator(
                  onRefresh: cart.refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: groups.length,
                    itemBuilder: (context, index) =>
                        _ShopGroupCard(group: groups[index], onOrder: _callThenOrder),
                  ),
                ),
    );
  }
}

class _ShopGroupCard extends StatelessWidget {
  final CartShopGroup group;
  final void Function(CartShopGroup group) onOrder;
  const _ShopGroupCard({required this.group, required this.onOrder});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(group.shopName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
            ),
            const Divider(height: 20),
            ...group.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${item.unit} · ${Formatters.rupees(item.unitPrice)}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      _QuantityStepper(
                        quantity: item.quantity,
                        onChanged: (q) => cart.setQuantity(item.productId, q),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              children: [
                Text('Subtotal: ${Formatters.rupees(group.subtotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton(
                  onPressed: () => onOrder(group),
                  child: const Text('Place Order'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: () => onChanged(quantity - 1),
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}
