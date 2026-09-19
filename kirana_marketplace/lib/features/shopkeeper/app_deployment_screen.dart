import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/env_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/shop_model.dart';

/// "App Generator & Configurator" -- Phase 2.2 of the white-label
/// ecosystem. Gives a shopkeeper two ways to get a shop-specific
/// customer app in front of their customers, without needing a
/// developer:
///
///   a) Dynamic / On-the-Fly UI -- share the Shop Code (or its link)
///      with customers; they enter it once in the generic customer app
///      (see ShopEntryScreen) and it locks itself to this shop.
///   b) Build Automation Config -- exports the `--dart-define` flags
///      (as a build_config.json a developer/CI pipeline can consume) for
///      producing a dedicated, shop-branded APK -- see the accompanying
///      `.github/workflows/build_apk.yml`.
class AppDeploymentScreen extends StatelessWidget {
  final ShopModel shop;
  const AppDeploymentScreen({super.key, required this.shop});

  static const _deepLinkScheme = 'kiranamandi://shop';

  String get _shareableLink => '$_deepLinkScheme/${shop.shopCode}';

  String get _buildConfigJson {
    final config = {
      'SHOP_ID': shop.id,
      'APP_NAME': shop.name,
      'PRIMARY_COLOR': (shop.primaryColor ?? '2E7D32').replaceFirst('#', ''),
      'SECONDARY_COLOR': (shop.secondaryColor ?? '').replaceFirst('#', ''),
      'API_BASE_URL': EnvConfig.apiBaseUrl.isNotEmpty
          ? EnvConfig.apiBaseUrl
          : 'https://your-backend.onrender.com',
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  String get _buildCommand {
    final c = jsonDecode(_buildConfigJson) as Map<String, dynamic>;
    final defines = c.entries
        .where((e) => (e.value as String).isNotEmpty)
        .map((e) => '--dart-define=${e.key}=${e.value}')
        .join(' \\\n  ');
    return 'flutter build apk \\\n  $defines';
  }

  Future<void> _copy(BuildContext context, String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Deployment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Get a branded app in front of your customers -- pick whichever fits.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            icon: Icons.link,
            title: 'Dynamic / On-the-Fly',
            subtitle:
                'No developer needed. Share your code -- customers enter it in the '
                'regular Kirana Mandi app and it locks to your shop automatically.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Shop Code',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                _CopyableBox(
                  text: shop.shopCode,
                  monospace: true,
                  large: true,
                  onCopy: () => _copy(context, 'Shop code', shop.shopCode),
                ),
                const SizedBox(height: 16),
                const Text('Shareable link',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                _CopyableBox(
                  text: _shareableLink,
                  monospace: true,
                  onCopy: () => _copy(context, 'Link', _shareableLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.build_outlined,
            title: 'Build Automation Config',
            subtitle:
                'For a developer or CI/CD pipeline (GitHub Actions, Codemagic) to '
                'produce a dedicated, pre-branded APK just for your shop.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('build_config.json',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                _CopyableBox(
                  text: _buildConfigJson,
                  monospace: true,
                  onCopy: () => _copy(context, 'build_config.json', _buildConfigJson),
                ),
                const SizedBox(height: 16),
                const Text('Equivalent build command',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                _CopyableBox(
                  text: _buildCommand,
                  monospace: true,
                  onCopy: () => _copy(context, 'Build command', _buildCommand),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (shop.primaryColor == null || shop.primaryColor!.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Tip: set a brand color in \"Edit Shop Profile\" first so both "
                'options above use it automatically.',
                style: TextStyle(color: AppColors.pending, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  foregroundColor: AppColors.primary,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _CopyableBox extends StatelessWidget {
  final String text;
  final bool monospace;
  final bool large;
  final VoidCallback onCopy;

  const _CopyableBox({
    required this.text,
    required this.onCopy,
    this.monospace = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontFamily: monospace ? 'monospace' : null,
                fontSize: large ? 20 : 13,
                fontWeight: large ? FontWeight.w700 : FontWeight.normal,
                letterSpacing: large ? 2 : 0,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy',
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
