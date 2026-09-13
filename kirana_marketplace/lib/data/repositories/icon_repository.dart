import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/product_icon_model.dart';

abstract class IconRepository {
  Future<List<ProductIconModel>> getAllIcons({bool activeOnly = true});
  Future<List<ProductIconModel>> getIconsByCategory(String categoryId);
  Future<void> create(ProductIconModel icon);
  Future<void> setActive(String id, bool isActive);
}

class SqliteIconRepository implements IconRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<List<ProductIconModel>> getAllIcons({bool activeOnly = true}) async {
    final db = await _db;
    final rows = await db.query(
      'icons',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'label ASC',
    );
    return rows.map(ProductIconModel.fromMap).toList();
  }

  @override
  Future<List<ProductIconModel>> getIconsByCategory(String categoryId) async {
    final db = await _db;
    final rows = await db.query(
      'icons',
      where: 'category_id = ? AND is_active = 1',
      whereArgs: [categoryId],
      orderBy: 'label ASC',
    );
    return rows.map(ProductIconModel.fromMap).toList();
  }

  @override
  Future<void> create(ProductIconModel icon) async {
    final db = await _db;
    await db.insert('icons', icon.toMap());
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    final db = await _db;
    await db.update('icons', {'is_active': isActive ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
