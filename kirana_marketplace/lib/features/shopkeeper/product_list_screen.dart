import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/product_model.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/product_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/product_tile.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  final ShopModel shop;
  const ProductListScreen({super.key, required this.shop});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<ProductModel> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products =
        await context.read<ProductRepository>().getProductsByShop(widget.shop.id);
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _toggleAvailability(ProductModel product) async {
    final auth = context.read<AuthController>().currentUser!;
    await context.read<ProductRepository>().setProductAvailability(
          product.id,
          !product.isAvailable,
          requestingUserId: auth.id,
        );
    _load();
  }

  Future<void> _delete(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove product?'),
        content: Text('This will remove "${product.name}" from your catalog.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final auth = context.read<AuthController>().currentUser!;
    await context
        .read<ProductRepository>()
        .deleteProduct(product.id, requestingUserId: auth.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProductFormScreen(shopId: widget.shop.id)),
          );
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  subtitle: 'Tap "Add Product" to build your catalog.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: _products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Dismissible(
                      key: ValueKey(product.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _delete(product);
                        return false; // _load() rebuilds the list itself
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.red),
                      ),
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProductFormScreen(
                                    shopId: widget.shop.id,
                                    existingProduct: product)),
                          );
                          _load();
                        },
                        child: ProductTile(
                          product: product,
                          trailing: Switch(
                            value: product.isAvailable,
                            onChanged: (_) => _toggleAvailability(product),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
