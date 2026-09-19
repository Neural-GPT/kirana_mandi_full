import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/env_config.dart';
import 'core/network/connectivity_service.dart';
import 'core/routing/app_router.dart';
import 'core/storage/session_storage.dart';
import 'core/theme/shop_theme_controller.dart';
import 'core/theme/theme_controller.dart';
import 'data/remote/api_client.dart';
import 'data/remote/http_admin_repository.dart';
import 'data/remote/http_auth_repository.dart';
import 'data/remote/http_call_log_repository.dart';
import 'data/remote/http_cart_repository.dart';
import 'data/remote/http_category_repository.dart';
import 'data/remote/http_icon_repository.dart';
import 'data/remote/http_order_repository.dart';
import 'data/remote/http_product_repository.dart';
import 'data/remote/http_region_repository.dart';
import 'data/remote/http_sales_repository.dart';
import 'data/remote/http_service_repository.dart';
import 'data/remote/http_shop_repository.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/call_log_repository.dart';
import 'data/repositories/cart_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/deployment_repository.dart';
import 'data/repositories/icon_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/region_repository.dart';
import 'data/repositories/sales_repository.dart';
import 'data/repositories/service_repository.dart';
import 'data/repositories/shop_repository.dart';
import 'data/repositories/sync_queue_repository.dart';
import 'data/repositories/tenant_repository.dart';
import 'features/authentication/auth_controller.dart';
import 'features/customer/cart_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One SessionStorage instance shared by AuthController and ApiClient so
  // both agree on where the user id / bearer token live.
  final sessionStorage = SessionStorage();

  // Always constructed (harmless when EnvConfig.useRemoteApi is false --
  // it's simply never called), so the same instance can be handed to
  // every Http*Repository below without threading conditionals through
  // each one individually.
  final apiClient = ApiClient(baseUrl: EnvConfig.apiBaseUrl, sessionStorage: sessionStorage);
  if (EnvConfig.useRemoteApi) {
    // Loads a previously-issued token into memory *before* runApp, so
    // SplashScreen's very first "who am I" request (GET /auth/me, via
    // HttpAuthRepository.getUserById) already carries it -- otherwise a
    // returning user would look logged-out for one frame and get
    // bounced to the role-select screen.
    await apiClient.restoreToken();
  }

  runApp(KiranaMandiApp(apiClient: apiClient, sessionStorage: sessionStorage));
}

class KiranaMandiApp extends StatelessWidget {
  final ApiClient apiClient;
  final SessionStorage sessionStorage;

  const KiranaMandiApp({super.key, required this.apiClient, required this.sessionStorage});

  @override
  Widget build(BuildContext context) {
    final useRemote = EnvConfig.useRemoteApi;

    return MultiProvider(
      providers: [
        // --- Cross-cutting services ---
        Provider<SessionStorage>.value(value: sessionStorage),
        ChangeNotifierProvider<ConnectivityService>(
          create: (_) => ConnectivityService(),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(),
        ),
        Provider<SyncQueueRepository>(create: (_) => SyncQueueRepository()),

        // --- Repositories (data layer) ---
        // Every repository is exposed via its abstract type. Which
        // concrete implementation gets bound below is the ONLY thing
        // that changes when EnvConfig.useRemoteApi flips -- nothing in
        // `features/` depends on SQLite or HTTP directly. Set
        // --dart-define=API_BASE_URL=https://your-backend to point the
        // whole app at the FastAPI backend (kirana_backend/) instead of
        // on-device SQLite (offline-only / single-device demo mode).
        if (useRemote) ...[
          Provider<RegionRepository>(create: (_) => HttpRegionRepository(apiClient)),
          Provider<CategoryRepository>(create: (_) => HttpCategoryRepository(apiClient)),
          Provider<ServiceRepository>(create: (_) => HttpServiceRepository(apiClient)),
          Provider<IconRepository>(create: (_) => HttpIconRepository(apiClient)),
          Provider<CallLogRepository>(create: (_) => HttpCallLogRepository(apiClient)),
          Provider<SalesRepository>(create: (_) => HttpSalesRepository(apiClient)),
          Provider<AdminRepository>(create: (_) => HttpAdminRepository(apiClient)),
          Provider<AuthRepository>(create: (_) => HttpAuthRepository(apiClient)),
          Provider<ShopRepository>(create: (_) => HttpShopRepository(apiClient)),
          Provider<ProductRepository>(create: (_) => HttpProductRepository(apiClient)),
          Provider<CartRepository>(create: (_) => HttpCartRepository(apiClient)),
          Provider<OrderRepository>(create: (_) => HttpOrderRepository(apiClient)),
          Provider<TenantRepository>(create: (_) => HttpTenantRepository(apiClient)),
          Provider<DeploymentRepository>(create: (_) => HttpDeploymentRepository(apiClient)),
        ] else ...[
          Provider<RegionRepository>(create: (_) => SqliteRegionRepository()),
          Provider<CategoryRepository>(create: (_) => SqliteCategoryRepository()),
          Provider<ServiceRepository>(create: (_) => SqliteServiceRepository()),
          Provider<IconRepository>(create: (_) => SqliteIconRepository()),
          Provider<CallLogRepository>(create: (_) => SqliteCallLogRepository()),
          Provider<SalesRepository>(create: (_) => SqliteSalesRepository()),
          Provider<AdminRepository>(create: (_) => SqliteAdminRepository()),

          // Auth: uses the fixed dev OTP by default. Real SMS via
          // textbee.dev turns on automatically once TEXTBEE_API_KEY and
          // TEXTBEE_DEVICE_ID are supplied via --dart-define.
          ProxyProvider<ConnectivityService, AuthRepository>(
            update: (_, connectivity, __) => EnvConfig.useTextbeeOtp
                ? TextbeeAuthRepository(
                    apiKey: EnvConfig.textbeeApiKey,
                    deviceId: EnvConfig.textbeeDeviceId,
                    connectivityService: connectivity,
                  )
                : DevAuthRepository(),
          ),

          Provider<ShopRepository>(create: (_) => SqliteShopRepository()),
          ProxyProvider<ShopRepository, ProductRepository>(
            update: (_, shopRepository, __) =>
                SqliteProductRepository(shopRepository: shopRepository),
          ),
          Provider<CartRepository>(create: (_) => SqliteCartRepository()),
          Provider<OrderRepository>(create: (_) => SqliteOrderRepository()),
          ProxyProvider<ShopRepository, TenantRepository>(
            update: (_, shopRepository, __) => SqliteTenantRepository(shopRepository),
          ),
        ],

        // White-label tenant context: resolves which single shop (if
        // any) this install is locked to (build-time via
        // EnvConfig.shopId, or at runtime via a Shop Code -- see
        // ShopEntryScreen) and exposes that shop's branding/theme.
        ChangeNotifierProxyProvider<TenantRepository, ShopThemeController>(
          create: (context) =>
              ShopThemeController(context.read<TenantRepository>(), apiClient),
          update: (context, tenantRepository, previous) =>
              previous ?? ShopThemeController(tenantRepository, apiClient),
        ),

        // --- App/session state ---
        ChangeNotifierProxyProvider<AuthRepository, AuthController>(
          create: (context) => AuthController(
            context.read<AuthRepository>(),
            sessionStorage: sessionStorage,
            apiClient: apiClient,
          ),
          update: (context, authRepository, previous) =>
              previous ??
              AuthController(authRepository,
                  sessionStorage: sessionStorage, apiClient: apiClient),
        ),

        // Cart: a customer's in-progress cart, grouped by shop. Loaded
        // once the logged-in customer id is known (see
        // CustomerShellScreen.initState). Persisted server-side (Http)
        // or via the on-device `cart_items` table (Sqlite) so it
        // survives app restarts either way.
        ChangeNotifierProxyProvider2<CartRepository, OrderRepository,
            CartController>(
          create: (context) => CartController(
            context.read<CartRepository>(),
            context.read<OrderRepository>(),
          ),
          update: (context, cartRepository, orderRepository, previous) =>
              previous ?? CartController(cartRepository, orderRepository),
        ),
      ],
      child: const _AppWithTheme(),
    );
  }
}

class _AppWithTheme extends StatelessWidget {
  const _AppWithTheme();

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final tenant = context.watch<ShopThemeController>();
    return MaterialApp(
      title: tenant.appName ?? AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: tenant.light(),
      darkTheme: tenant.dark(),
      themeMode: themeController.themeMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/splash',
    );
  }
}
