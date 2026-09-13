import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';

/// A slim banner that appears whenever the device has no network
/// connectivity. All data in this app is read from/written to the local
/// SQLite database, so browsing and catalog management keep working
/// offline -- this banner just sets expectations for anything that
/// genuinely needs the network (sending a real OTP SMS, and once the app
/// is migrated to the Aiven-hosted API, fetching/pushing live data).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityService>().isOnline;
    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.warning.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "You're offline. Showing saved data -- some actions need a connection.",
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
