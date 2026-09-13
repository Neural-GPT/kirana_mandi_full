import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../authentication/auth_controller.dart';
import '../customer/cart_controller.dart';

/// Shared settings screen used by both the shopkeeper and admin
/// dashboards (reached via the gear icon). Customers aren't authenticated
/// in this app, so they don't get a settings screen -- there's nothing
/// account-specific to configure.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to verify your phone again to log back in."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AuthController>().logout();
    if (!context.mounted) return;
    // Clear any in-memory cart state so a different customer logging in
    // on this device doesn't see the previous customer's cart.
    context.read<CartController>().clearOnLogout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  Future<void> _callCompany() async {
    final uri = Uri(scheme: 'tel', path: AppConstants.companyPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showContactUs(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConstants.companyName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.call_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(AppConstants.companyPhone),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _callCompany();
            },
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final themeController = context.watch<ThemeController>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(user.name?.isNotEmpty == true
                    ? user.name!
                    : 'Phone: ${user.phone}'),
                subtitle: Text(_roleLabel(user.role)),
              ),
            ),
          const SizedBox(height: 16),
          const _SectionHeader('Appearance'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark theme'),
              subtitle: const Text('Use a dark color scheme across the app'),
              value: themeController.isDark,
              onChanged: (v) => themeController.setDark(v),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Support'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Contact Us'),
                  subtitle: Text(AppConstants.companyName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showContactUs(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: Text('${AppConstants.appName} · v0.1.0'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Log Out',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case AppConstants.roleSuperAdmin:
        return 'Super Admin';
      case AppConstants.roleAdmin:
        return 'Admin';
      case AppConstants.roleShopkeeper:
        return 'Shopkeeper';
      default:
        return 'Customer';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textSecondary)),
    );
  }
}
