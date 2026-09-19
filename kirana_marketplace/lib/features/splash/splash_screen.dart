import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/env_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shop_theme_controller.dart';
import '../../core/widgets/shop_logo.dart';
import '../../data/repositories/shop_repository.dart';
import '../authentication/auth_controller.dart';

/// First screen shown on cold start. Tries to restore a previously logged
/// in session (customer, shopkeeper, or admin) from disk and routes
/// straight to the right place.
///
/// Hardened against hanging: every async step has a timeout, the whole
/// bootstrap is wrapped in try/catch with a safe fallback route, and if
/// navigation still somehow hasn't happened after a few seconds a manual
/// "Continue" button appears so the user is never stuck looking at a
/// spinner with no way forward.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;
  bool _showManualContinue = false;
  Timer? _stuckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());

    // Safety net: if nothing has navigated within 6 seconds (DB stuck,
    // plugin not responding, etc.), offer a manual way out instead of an
    // infinite spinner.
    _stuckTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_navigated) {
        setState(() => _showManualContinue = true);
      }
    });
  }

  @override
  void dispose() {
    _stuckTimer?.cancel();
    super.dispose();
  }

  void _goTo(String route) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _stuckTimer?.cancel();
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _bootstrap() async {
    try {
      final auth = context.read<AuthController>();
      await auth.restoreSession().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
      if (!mounted || _navigated) return;

      final user = auth.currentUser;
      if (user == null) {
        // Build Automation white-label install (EnvConfig.shopId baked
        // in at build time): this is a customer-only, single-shop app --
        // skip role selection (and the "is this a shopkeeper/admin
        // device" question) entirely and go straight to customer login.
        // A Dynamic-mode install with a runtime-chosen shop still goes
        // through '/', since it's the same generic app everyone else
        // uses (see role_select_screen.dart's "Have a shop code?" entry).
        _goTo(EnvConfig.isWhiteLabelBuild ? '/customer/login' : '/');
        return;
      }

      switch (user.role) {
        case AppConstants.roleAdmin:
        case AppConstants.roleSuperAdmin:
          _goTo('/admin/dashboard');
          return;
        case AppConstants.roleShopkeeper:
          final shopRepo = context.read<ShopRepository>();
          final shop = await shopRepo
              .getShopByOwnerId(user.id)
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (!mounted || _navigated) return;
          _goTo(shop == null ? '/shopkeeper/shop-setup' : '/shopkeeper/dashboard');
          return;
        case AppConstants.roleCustomer:
          _goTo('/customer/home');
          return;
        default:
          _goTo('/');
      }
    } catch (_) {
      // Whatever went wrong, don't leave the user staring at a spinner --
      // fall back to the role-select screen (or straight to customer
      // login for a white-label build), the same as a fresh install.
      _goTo(EnvConfig.isWhiteLabelBuild ? '/customer/login' : '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<ShopThemeController>();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            tenant.isLockedToShop
                ? ShopLogo(logoUrl: tenant.branding?.logoUrl, size: 64)
                : const Icon(Icons.storefront, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(tenant.appName ?? AppConstants.appName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            if (_showManualContinue) ...[
              const SizedBox(height: 24),
              const Text(
                "This is taking longer than expected.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () =>
                    _goTo(EnvConfig.isWhiteLabelBuild ? '/customer/login' : '/'),
                child: const Text('Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
