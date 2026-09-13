import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../authentication/auth_controller.dart';
import 'cart_controller.dart';
import 'cart_screen.dart';
import 'customer_home_screen.dart';
import 'orders_screen.dart';
import 'product_search_screen.dart';

/// Bottom-nav shell for the logged-in customer experience: Home (browse
/// by area), Search, Cart (grouped by shop), and Orders (current +
/// history with delivery status). Replaces the old "customer just lands
/// on CustomerHomeScreen with no account" flow now that customers log in.
class CustomerShellScreen extends StatefulWidget {
  const CustomerShellScreen({super.key});

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerId = context.read<AuthController>().currentUser?.id;
      if (customerId != null) {
        context.read<CartController>().loadForCustomer(customerId);
      }
    });
  }

  static const _tabs = [
    CustomerHomeScreen(),
    ProductSearchScreen(),
    CartScreen(),
    OrdersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartController>().itemCount;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders'),
        ],
      ),
    );
  }
}
