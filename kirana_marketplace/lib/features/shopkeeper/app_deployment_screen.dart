import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/env_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/deployment_repository.dart';

/// "App Generator & Configurator" -- Phase 2.2 of the white-label
/// ecosystem. Primary flow: the shopkeeper taps **Generate My App** and
/// gets back a unique, installable APK -- its own Android application id
/// (installs alongside other shops' apps instead of overwriting them),
/// its own launcher name, and its own launcher icon, all set at the
/// system level by the CI build (see .github/workflows/build_apk.yml),
/// not just inside the Flutter app. That's the one link a shopkeeper
/// hands to customers.
///
/// Two secondary options below it, for cases the generated APK doesn't
/// cover:
///   - Instant Preview -- a Shop Code customers can type into the
///     regular shared app for a no-install look, before an APK exists.
///   - Manual Build Config -- the raw `--dart-define` values, for a
///     developer building outside this backend's CI.
class AppDeploymentScreen extends StatefulWidget {
  final ShopModel shop;
  const AppDeploymentScreen({super.key, required this.shop});

  @override
  State<AppDeploymentScreen> createState() => _AppDeploymentScreenState();
}

class _AppDeploymentScreenState extends State<AppDeploymentScreen> {
  static const _deepLinkScheme = 'kiranamandi://shop';

  ApkStatus? _status;
  bool _requesting = false;
  bool _polling = false;
  String? _error;
  Timer? _pollTimer;

  bool get _backendAvailable => EnvConfig.useRemoteApi;

  @override
  void initState() {
    super.initState();
    if (_backendAvailable) _refreshStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final status =
          await context.read<DeploymentRepository>().getApkStatus(widget.shop.id);
      if (!mounted) return;
      setState(() => _status = status);
      if (status.isReady) _stopPolling();
    } catch (_) {
      // Quiet on the initial background check -- _generate()'s own error
      // handling covers the user-initiated path.
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _polling = true;
    var elapsed = Duration.zero;
    const interval = Duration(seconds: 10);
    const timeout = Duration(minutes: 10); // typical Flutter CI build is 3-6 min
    _pollTimer = Timer.periodic(interval, (timer) async {
      elapsed += interval;
      await _refreshStatus();
      if (!mounted) return;
      if (_status?.isReady == true || elapsed >= timeout) {
        _stopPolling();
        if (elapsed >= timeout && _status?.isReady != true) {
          setState(() => _error =
              'Still building -- this is taking longer than usual. Check back '
              'in a few minutes, or open the build log below.');
        }
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    if (mounted) setState(() => _polling = false);
  }

  Future<void> _generate() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final result =
          await context.read<DeploymentRepository>().generateApk(widget.shop.id);
      if (!mounted) return;
      if (result.triggered) {
        setState(() => _requesting = false);
        _startPolling();
      } else {
        setState(() {
          _requesting = false;
          _error = result.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _error = "Couldn't start the build. Please try again.";
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copy(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
    }
  }

  String get _shareableLink => '$_deepLinkScheme/${widget.shop.shopCode}';

  String get _buildConfigJson {
    final config = {
      'SHOP_ID': widget.shop.id,
      'APP_NAME': widget.shop.name,
      'PRIMARY_COLOR': (widget.shop.primaryColor ?? '2E7D32').replaceFirst('#', ''),
      'SECONDARY_COLOR': (widget.shop.secondaryColor ?? '').replaceFirst('#', ''),
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
    return 'flutter build apk --split-per-abi \\\n  $defines';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Deployment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Generate your own branded app -- a unique icon, name, and catalog, '
            'ready to share with your customers.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_backendAvailable) _buildGenerateCard() else _buildBackendMissingCard(),
          const SizedBox(height: 24),
          const Text('More options',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          _SectionCard(
            icon: Icons.link,
            title: 'Instant Preview (no install needed)',
            subtitle:
                'Share your code so someone can look at your shop right inside the '
                'regular Kirana Mandi app, before you have an APK ready.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Shop Code',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                _CopyableBox(
                  text: widget.shop.shopCode,
                  monospace: true,
                  large: true,
                  onCopy: () => _copy('Shop code', widget.shop.shopCode),
                ),
                const SizedBox(height: 16),
                const Text('Shareable link',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                _CopyableBox(
                  text: _shareableLink,
                  monospace: true,
                  onCopy: () => _copy('Link', _shareableLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.build_outlined,
            title: 'Manual Build Config',
            subtitle:
                'For a developer building the app outside this dashboard '
                '(their own machine or CI pipeline).',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('build_config.json',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                _CopyableBox(
                  text: _buildConfigJson,
                  monospace: true,
                  onCopy: () => _copy('build_config.json', _buildConfigJson),
                ),
                const SizedBox(height: 16),
                const Text('Equivalent build command',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                _CopyableBox(
                  text: _buildCommand,
                  monospace: true,
                  onCopy: () => _copy('Build command', _buildCommand),
                ),
              ],
            ),
          ),
          if (widget.shop.primaryColor == null || widget.shop.primaryColor!.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                "Tip: set a brand color (and a logo, for your app icon) in "
                '"Edit Shop Profile" first so everything above uses it automatically.',
                style: TextStyle(color: AppColors.pending, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackendMissingCard() {
    return _SectionCard(
      icon: Icons.cloud_off,
      title: 'Generate My App',
      subtitle:
          "This build isn't connected to a backend, so app generation isn't "
          'available here -- use the Manual Build Config below with a developer, '
          'or connect a backend (API_BASE_URL) to unlock one-tap generation.',
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildGenerateCard() {
    final status = _status;
    return Card(
      color: AppColors.primary.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.rocket_launch_outlined),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Generate My App',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Builds a ready-to-install APK with your shop's name, icon, and "
              "catalog baked in -- give the download link to your customers.",
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (status?.isReady == true) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your app is ready',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          if (status!.applicationId != null)
                            Text(status.applicationId!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openUrl(status.downloadUrl!),
                      icon: const Icon(Icons.download),
                      label: const Text('Download APK'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () => _copy('Download link', status.downloadUrl!),
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy link to share with customers',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _requesting ? null : _generate,
                child: const Text('Rebuild (e.g. after updating your logo or catalog)'),
              ),
            ] else ...[
              if (_polling) ...[
                const Row(
                  children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Expanded(child: Text('Building your app -- usually a few minutes...')),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: (_requesting || _polling) ? null : _generate,
                icon: _requesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch),
                label: Text(_polling ? 'Building...' : 'Generate My App'),
              ),
            ],
          ],
        ),
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
