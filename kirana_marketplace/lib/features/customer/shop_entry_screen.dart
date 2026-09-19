import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shop_theme_controller.dart';

/// "Dynamic / On-the-Fly UI" white-label entry point: lets a customer on
/// the generic (non-shop-specific) build type in a shopkeeper-shared
/// Shop Code -- or arrive here already carrying one from a deep link --
/// to lock this install to that one shop's catalog and branding, without
/// needing a separately-built APK (see ARCHITECTURAL GOALS > Phase 2.2a).
///
/// Once locked, [ShopThemeController.isLockedToShop] is true and the
/// rest of the customer experience (CustomerHomeScreen, search, cart,
/// checkout) automatically narrows to that shop -- see
/// CustomerShellScreen.initState.
class ShopEntryScreen extends StatefulWidget {
  /// Pre-fills the code, e.g. when opened from a deep link that already
  /// carries one (`kiranamandi://shop/ABCD1234`).
  final String? initialCode;

  const ShopEntryScreen({super.key, this.initialCode});

  @override
  State<ShopEntryScreen> createState() => _ShopEntryScreenState();
}

class _ShopEntryScreenState extends State<ShopEntryScreen> {
  late final TextEditingController _codeController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _submitting = true);
    final tenant = context.read<ShopThemeController>();
    final ok = await tenant.lockToShopCode(code);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, '/customer/login', (route) => false);
    } else if (tenant.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tenant.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Shop Code')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.storefront, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              "Got a shop's code or link?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the shop code your shopkeeper shared with you to '
              'jump straight into their catalog -- ${AppConstants.appName} '
              'will remember it next time you open the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 4),
              decoration: const InputDecoration(
                hintText: 'ABCD1234',
                counterText: '',
              ),
              maxLength: 12,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Continue'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/customer/login', (route) => false),
              child: const Text("I don't have a code -- browse all shops"),
            ),
          ],
        ),
      ),
    );
  }
}
