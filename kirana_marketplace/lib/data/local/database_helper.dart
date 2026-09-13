import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'seed_data.dart';

/// Owns the local SQLite database used for development/pre-deployment
/// (PRD §3 "Development / Offline Database").
///
/// IMPORTANT: This is a *development* substitute for the production
/// PostgreSQL-backed API. Every table here mirrors what the production
/// API/DB schema should look like, and every repository in
/// `data/repositories` is written against an abstract interface so this
/// SQLite implementation can be swapped for an HTTP-backed implementation
/// later without touching the UI (see AGENT_NOTES.md / PRD §3, §40).
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;
  static Future<Database>? _initFuture;

  Future<Database> get database async {
    if (_db != null) return _db!;
    // Memoize the in-flight initialization. On startup, many repositories
    // (Region, Shop, Product, Sales, ...) each call this getter within the
    // same frame. Without memoizing, a "check _db == null, then set it"
    // pattern lets several of them race to open/seed the database at the
    // same time -- on a real device (slower storage than an emulator)
    // this can stall or throw a constraint error during double-seeding,
    // and since nothing was awaiting a shared future, the app can appear
    // to hang indefinitely (e.g. stuck on the splash screen). Memoizing
    // means every concurrent caller awaits the exact same Future.
    _initFuture ??= _initDb();
    _db = await _initFuture!;
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kirana_mandi.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
    if (oldVersion < 3) {
      await _createV3Tables(db);
    }
  }

  Future<void> _createV3Tables(Database db) async {
    // Cart: persisted (not just in-memory) so a customer's cart survives
    // an app restart or a brief network drop -- part of "offline
    // functionality and cache". One row per distinct product a customer
    // has added; `quantity` is updated in place rather than inserting
    // duplicate rows.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        shop_id TEXT NOT NULL,
        shop_name TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        added_at TEXT NOT NULL,
        UNIQUE (customer_id, product_id)
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cart_items_customer ON cart_items (customer_id);');

    // Orders: one row per shop per checkout (a mixed-shop cart becomes
    // several orders, grouped by shop -- see OrderRepository). Customers
    // aren't paying in-app (no payment gateway in scope), so this models
    // a "confirm with the shop, then order" request/accept flow rather
    // than e-commerce checkout.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        shop_id TEXT NOT NULL,
        shop_name TEXT NOT NULL,
        shop_phone TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'placed',
        delivery_boy_phone TEXT,
        total_amount REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES users (id),
        FOREIGN KEY (shop_id) REFERENCES shops (id)
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders (customer_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_shop ON orders (shop_id);');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id)
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items (order_id);');
  }

  Future<void> _createV2Tables(Database db) async {
    // Call logs: recorded whenever a customer taps "Call Shop" so the
    // shopkeeper can see who's been reaching out and when (PRD extension).
    // Customers aren't authenticated in this app, so entries are
    // effectively anonymous timestamps unless a caller name is captured.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS call_logs (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        caller_label TEXT,
        called_at TEXT NOT NULL,
        FOREIGN KEY (shop_id) REFERENCES shops (id)
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_call_logs_shop ON call_logs (shop_id);');

    // Daily sales: shopkeeper logs what sold today so the app can compute
    // revenue and power the analytics screen (daily/weekly/monthly).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        sale_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (shop_id) REFERENCES shops (id)
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_shop_date ON sale_items (shop_id, sale_date);');

    // OTP codes generated on-device for the textbee.dev SMS flow. Not
    // needed by DevAuthRepository (fixed code), only by
    // TextbeeAuthRepository. Kept short-lived and single-use.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS otp_codes (
        phone TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        expires_at TEXT NOT NULL
      );
    ''');

    // Pending-write log. Every offline-capable mutation (shop/product
    // create or update, daily sales entry, etc.) appends a row here. Once
    // the app is migrated to talk to the Aiven-hosted Postgres API, a
    // background sync worker drains this queue -- see README "Offline
    // support" section. For now it also doubles as a lightweight audit
    // trail of local writes.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE regions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE services (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE icons (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        category_id TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        phone TEXT NOT NULL UNIQUE,
        name TEXT,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE shops (
        id TEXT PRIMARY KEY,
        owner_user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        alt_phone TEXT,
        description TEXT,
        category_id TEXT,
        region_id TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        formatted_address TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        is_available INTEGER NOT NULL DEFAULT 1,
        home_delivery INTEGER NOT NULL DEFAULT 0,
        delivery_radius_km REAL,
        delivery_fee REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (owner_user_id) REFERENCES users (id),
        FOREIGN KEY (region_id) REFERENCES regions (id)
      );
    ''');

    await db.execute('''
      CREATE TABLE shop_services (
        shop_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        PRIMARY KEY (shop_id, service_id),
        FOREIGN KEY (shop_id) REFERENCES shops (id),
        FOREIGN KEY (service_id) REFERENCES services (id)
      );
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category_id TEXT,
        price REAL NOT NULL,
        unit TEXT NOT NULL,
        icon_id TEXT NOT NULL,
        is_available INTEGER NOT NULL DEFAULT 1,
        description TEXT,
        FOREIGN KEY (shop_id) REFERENCES shops (id)
      );
    ''');

    await db.execute('CREATE INDEX idx_shops_region ON shops (region_id);');
    await db.execute('CREATE INDEX idx_products_shop ON products (shop_id);');
    await db.execute('CREATE INDEX idx_products_name ON products (name);');

    await _createV2Tables(db);
    await _createV3Tables(db);

    await seedDatabase(db);
  }

  /// Used by dev tooling / tests that want a clean slate.
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kirana_mandi.db');
    await deleteDatabase(path);
    _db = null;
    _initFuture = null;
    await database;
  }
}
