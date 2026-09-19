import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/shop_branding_model.dart';
import '../../data/remote/api_client.dart';
import '../../data/repositories/tenant_repository.dart';
import '../constants/env_config.dart';
import 'app_theme.dart';

/// The "TenantProvider" for the white-labeled app ecosystem: figures out
/// which single shop (if any) this install is locked to, fetches that
/// shop's branding, and exposes a ready-to-use [ThemeData] built from its
/// colors. Every screen that needs to know "are we white-labeled, and to
/// which shop" reads this via `context.watch<ShopThemeController>()`.
///
/// A shop lock can come from two places (see ARCHITECTURAL GOALS in the
/// refactor brief):
///   a) Build Automation: [EnvConfig.shopId], baked in at build time via
///      `--dart-define=SHOP_ID=...`. Permanent for this install -- see
///      [isBuildLocked].
///   b) Dynamic / On-the-Fly: chosen at runtime by the customer entering
///      a Shop Code or opening a shop's deep link (see ShopEntryScreen),
///      persisted locally so it survives app restarts, and changeable
///      via [clearLock] (e.g. a "Switch Shop" action in Settings).
class ShopThemeController extends ChangeNotifier {
  static const _kRuntimeShopIdKey = 'white_label_runtime_shop_id';

  final TenantRepository _tenantRepository;
  final ApiClient _apiClient;

  ShopThemeController(this._tenantRepository, this._apiClient) {
    _bootstrap();
  }

  String? _shopId;
  ShopBrandingModel? _branding;
  bool _loading = false;
  String? _error;

  /// True when this install can never be un-locked from its shop (a
  /// Build Automation / shop-specific APK) -- as opposed to a Dynamic
  /// build where [clearLock] lets the customer pick a different shop.
  bool get isBuildLocked => EnvConfig.isWhiteLabelBuild;

  /// True whenever the app should behave as a single-shop experience,
  /// regardless of *how* it got locked to that shop.
  bool get isLockedToShop => _shopId != null && _shopId!.isNotEmpty;

  String? get shopId => _shopId;
  ShopBrandingModel? get branding => _branding;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> _bootstrap() async {
    // Build-time lock always wins and needs no persistence check.
    if (EnvConfig.isWhiteLabelBuild) {
      await lockToShop(EnvConfig.shopId, persist: false);
      return;
    }
    // Otherwise, see if a Dynamic-mode choice was made on a previous run.
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedShopId = prefs.getString(_kRuntimeShopIdKey);
      if (savedShopId != null && savedShopId.isNotEmpty) {
        await lockToShop(savedShopId, persist: false);
      }
    } catch (_) {
      // No saved shop -- fine, app just runs in normal multi-shop mode.
    }
  }

  /// Resolves a customer-entered Shop Code to a shop_id, then locks to
  /// it. Used by ShopEntryScreen. Returns true on success.
  Future<bool> lockToShopCode(String shopCode) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final id = await _tenantRepository.resolveShopCode(shopCode);
      await lockToShop(id);
      return true;
    } catch (e) {
      _error = "Couldn't find a shop with that code. Please check and try again.";
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Locks the app to [shopId] and loads its branding. [persist]
  /// controls whether this choice survives a restart -- true for a
  /// runtime (Dynamic-mode) choice, false when re-applying a lock that's
  /// already durable another way (build-time define, or a value just
  /// re-read from storage).
  Future<void> lockToShop(String shopId, {bool persist = true}) async {
    _shopId = shopId;
    _apiClient.setTenantShopId(shopId);
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _branding = await _tenantRepository.getBranding(shopId);
      _error = null;
    } catch (e) {
      _error = 'Could not load this shop. Please check your connection.';
    } finally {
      _loading = false;
      notifyListeners();
    }

    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kRuntimeShopIdKey, shopId);
      } catch (_) {
        // Not fatal -- the lock just won't survive an app restart.
      }
    }
  }

  /// Un-locks a Dynamic-mode build so the customer can pick a different
  /// shop (e.g. "Switch Shop" in Settings). No-op (and should be hidden
  /// in the UI) for a Build Automation install -- see [isBuildLocked].
  Future<void> clearLock() async {
    if (isBuildLocked) return;
    _shopId = null;
    _branding = null;
    _apiClient.setTenantShopId(null);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRuntimeShopIdKey);
    } catch (_) {
      // Not fatal.
    }
  }

  Future<void> refreshBranding() async {
    if (_shopId != null) await lockToShop(_shopId!, persist: false);
  }

  // --- Theming ---

  Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    final intValue = int.tryParse(value, radix: 16);
    return intValue == null ? null : Color(intValue);
  }

  /// The primary seed color for this build/session: an explicit
  /// `--dart-define=PRIMARY_COLOR` wins (Build Automation can pin an
  /// exact brand color independent of what's saved on the shop record),
  /// then the shop's own saved `primary_color`, then null (caller falls
  /// back to the default app palette).
  Color? get _seedPrimary =>
      _parseHex(EnvConfig.primaryColorOverride) ?? _parseHex(_branding?.primaryColor);

  Color? get _seedSecondary =>
      _parseHex(EnvConfig.secondaryColorOverride) ?? _parseHex(_branding?.secondaryColor);

  /// A branded [ThemeData] when a shop (and a color for it) is known,
  /// otherwise the app's default theme -- see AppTheme.light/dark.
  ThemeData light() => _buildTheme(dark: false);
  ThemeData dark() => _buildTheme(dark: true);

  ThemeData _buildTheme({required bool dark}) {
    final seed = _seedPrimary;
    if (seed == null) return dark ? AppTheme.dark : AppTheme.light;
    return AppTheme.branded(
      primary: seed,
      secondary: _seedSecondary,
      dark: dark,
    );
  }

  /// Display name for this build: an explicit `--dart-define=APP_NAME`
  /// wins, then the locked shop's own name, then null (caller falls back
  /// to AppConstants.appName).
  String? get appName {
    if (EnvConfig.appNameOverride.isNotEmpty) return EnvConfig.appNameOverride;
    return _branding?.shopName;
  }
}
