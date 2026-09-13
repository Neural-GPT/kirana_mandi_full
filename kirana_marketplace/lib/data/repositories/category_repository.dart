import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/category_model.dart';

abstract class CategoryRepository {
  Future<List<CategoryModel>> getByType(String type, {bool activeOnly = true});
  Future<CategoryModel?> getById(String id);
  Future<void> create(CategoryModel category);
  Future<void> update(CategoryModel category);
  Future<void> setActive(String id, bool isActive);
}

class SqliteCategoryRepository implements CategoryRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Future<List<CategoryModel>> getByType(String type,
      {bool activeOnly = true}) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: activeOnly ? 'type = ? AND is_active = 1' : 'type = ?',
      whereArgs: [type],
      orderBy: 'name ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  @override
  Future<CategoryModel?> getById(String id) async {
    final db = await _db;
    final rows =
        await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return CategoryModel.fromMap(rows.first);
  }

  @override
  Future<void> create(CategoryModel category) async {
    final db = await _db;
    await db.insert('categories', category.toMap());
  }

  @override
  Future<void> update(CategoryModel category) async {
    final db = await _db;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    final db = await _db;
    await db.update('categories', {'is_active': isActive ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
