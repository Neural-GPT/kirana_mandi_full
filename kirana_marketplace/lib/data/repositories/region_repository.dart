import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../models/region_model.dart';

/// Abstract contract. The rest of the app only depends on this interface,
/// so the SQLite implementation used in development can later be swapped
/// for one that calls the production API without touching any screen
/// (PRD §3, §40).
abstract class RegionRepository {
  Future<List<RegionModel>> getAllRegions({bool activeOnly = true});
  Future<RegionModel?> getRegionById(String id);
  Future<void> createRegion(RegionModel region);
  Future<void> updateRegion(RegionModel region);
  Future<void> setRegionActive(String id, bool isActive);

  /// Used when a shopkeeper types a new area name during shop setup: if
  /// an active region with that name already exists (case-insensitive,
  /// whitespace-trimmed -- e.g. an admin already created "Sanjay Place"),
  /// reuse it instead of creating a duplicate. Otherwise creates a new
  /// one, which then shows up for every other shopkeeper/admin too.
  Future<RegionModel> findOrCreateByName(String name);
}

class SqliteRegionRepository implements RegionRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<List<RegionModel>> getAllRegions({bool activeOnly = true}) async {
    final db = await _db;
    final rows = await db.query(
      'regions',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(RegionModel.fromMap).toList();
  }

  @override
  Future<RegionModel?> getRegionById(String id) async {
    final db = await _db;
    final rows = await db.query('regions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return RegionModel.fromMap(rows.first);
  }

  @override
  Future<void> createRegion(RegionModel region) async {
    final db = await _db;
    await db.insert('regions', region.toMap());
  }

  @override
  Future<void> updateRegion(RegionModel region) async {
    final db = await _db;
    await db.update('regions', region.toMap(),
        where: 'id = ?', whereArgs: [region.id]);
  }

  @override
  Future<void> setRegionActive(String id, bool isActive) async {
    final db = await _db;
    await db.update('regions', {'is_active': isActive ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<RegionModel> findOrCreateByName(String name) async {
    final trimmed = name.trim();
    final db = await _db;
    // SQLite's default collation for LIKE/`=` on TEXT is case-sensitive
    // for non-ASCII but case-insensitive for ASCII with COLLATE NOCASE;
    // being explicit here avoids relying on column-default collation.
    final rows = await db.query(
      'regions',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [trimmed],
    );
    if (rows.isNotEmpty) {
      return RegionModel.fromMap(rows.first);
    }
    final region = RegionModel(id: _uuid.v4(), name: trimmed);
    await db.insert('regions', region.toMap());
    return region;
  }
}
