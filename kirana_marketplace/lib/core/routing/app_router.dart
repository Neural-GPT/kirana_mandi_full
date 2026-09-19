import 'package:flutter/material.dart';
import '../../data/models/product_model.dart';
import '../../data/models/shop_model.dart';
import '../../features/authentication/admin_login_screen.dart';
import '../../features/authentication/otp_screen.dart';
import '../../features/authentication/phone_entry_screen.dart';
import '../../features/authentication/role_select_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/customer/customer_login_screen.dart';
import '../../features/customer/customer_shell_screen.dart';
import '../../features/customer/product_search_screen.dart';
import '../../features/customer/shop_entry_screen.dart';
import '../../features/customer/shop_list_screen.dart';
import '../../features/customer/shop_profile_screen.dart';
import '../../features/shopkeeper/app_deployment_screen.dart';
import '../../features/shopkeeper/product_form_screen.dart';
import '../../features/shopkeeper/product_list_screen.dart';
import '../../features/shopkeeper/shop_setup_screen.dart';
import '../../features/shopkeeper/shopkeeper_dashboard_screen.dart';
import '../../features/splash/splash_screen.dart';

/// Single place that turns a route name + arguments into a screen. Keeping
/// this centralised (rather than scattering MaterialPageRoute calls) makes
/// it easy to see the whole navigation graph of the app at a glance.
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Dedicated route name for the splash/bootstrap screen. Deliberately
      // NOT set via MaterialApp's `home:` -- that would silently register
      // '/' to always mean SplashScreen for every future navigation (not
      // just the very first launch), so SplashScreen's own
      // `Navigator.pushReplacementNamed(context, '/')` would resolve right
      // back to itself instead of RoleSelectScreen -- an infinite
      // init-bootstrap-navigate-init loop. Giving it its own name avoids
      // the collision entirely.
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case '/':
        return MaterialPageRoute(builder: (_) => const RoleSelectScreen());

      case '/phone':
        final role = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => PhoneEntryScreen(role: role));

      case '/otp':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => OtpScreen(
            phone: args['phone'] as String,
            role: args['role'] as String,
            name: args['name'] as String?,
            debugOtp: args['debugOtp'] as String?,
          ),
        );

      case '/admin/login':
        return MaterialPageRoute(builder: (_) => const AdminLoginScreen());

      case '/customer/login':
        return MaterialPageRoute(builder: (_) => const CustomerLoginScreen());

      case '/customer/home':
        return MaterialPageRoute(builder: (_) => const CustomerShellScreen());

      case '/customer/shops':
        final regionId = settings.arguments as String;
        return MaterialPageRoute(
            builder: (_) => ShopListScreen(regionId: regionId));

      case '/customer/shop':
        final shopId = settings.arguments as String;
        return MaterialPageRoute(
            builder: (_) => ShopProfileScreen(shopId: shopId));

      case '/customer/search':
        return MaterialPageRoute(builder: (_) => const ProductSearchScreen());

      case '/shop-entry':
        final code = settings.arguments as String?;
        return MaterialPageRoute(
            builder: (_) => ShopEntryScreen(initialCode: code));

      case '/shopkeeper/dashboard':
        return MaterialPageRoute(
            builder: (_) => const ShopkeeperDashboardScreen());

      case '/shopkeeper/shop-setup':
        final shop = settings.arguments as ShopModel?;
        return MaterialPageRoute(
            builder: (_) => ShopSetupScreen(existingShop: shop));

      case '/shopkeeper/products':
        final shop = settings.arguments as ShopModel;
        return MaterialPageRoute(builder: (_) => ProductListScreen(shop: shop));

      case '/shopkeeper/product-form':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ProductFormScreen(
            shopId: args['shopId'] as String,
            existingProduct: args['product'] as ProductModel?,
          ),
        );

      case '/shopkeeper/app-deployment':
        final shop = settings.arguments as ShopModel;
        return MaterialPageRoute(
            builder: (_) => AppDeploymentScreen(shop: shop));

      case '/admin/dashboard':
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
