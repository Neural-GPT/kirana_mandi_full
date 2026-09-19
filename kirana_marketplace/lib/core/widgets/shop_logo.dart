import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A shop's logo, shown wherever the app is white-labeled (splash,
/// single-shop home, shop profile) -- backed by [CachedNetworkImage] so
/// the same URL is decoded once and reused from memory/disk on every
/// later frame or screen, instead of every rebuild re-hitting the
/// network and re-decoding the PNG/JPEG (the "recommendations" in
/// PERFORMANCE.md at the repo root explain why that matters at list
/// scale; this is the same fix applied to the one branding image that
/// appears repeatedly across screens for a locked-in shop).
///
/// Falls back to a plain storefront icon when [logoUrl] is null/empty or
/// fails to load -- never lets a bad URL block or blank out the header
/// it sits in.
class ShopLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;

  const ShopLogo({super.key, required this.logoUrl, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 4);
    if (logoUrl == null || logoUrl!.isEmpty) {
      return _fallback(radius);
    }
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _fallback(radius, loading: true),
        errorWidget: (context, url, error) => _fallback(radius),
        // Decode at display size rather than native resolution -- a
        // shopkeeper-uploaded logo can be several megapixels; asking
        // the image cache to decode it down to the size it's actually
        // shown at avoids holding a needlessly large bitmap in memory.
        memCacheWidth: (size * 3).round(),
      ),
    );
  }

  Widget _fallback(BorderRadius radius, {bool loading = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: loading
          ? SizedBox(
              width: size * 0.35,
              height: size * 0.35,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.storefront, color: AppColors.primary, size: size * 0.55),
    );
  }
}
