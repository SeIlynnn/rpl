import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/game_category.dart';
import '../../domain/entities/game_item.dart';
import 'local_data_source.dart';

class SqfliteDataSource implements LocalDataSource {
  Database? _db;

  @override
  Future<void> initDb() async {
    if (_db != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'companion_app.db');
    
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            iconPath TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            categoryId INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            imagePath TEXT,
            stats TEXT,
            FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // --- CATEGORIES ---
  @override
  Future<List<GameCategory>> getCategories() async {
    final maps = await _db!.query('categories');
    return maps.map((json) => GameCategory.fromJson(json)).toList();
  }

  @override
  Future<int> insertCategory(GameCategory category) async {
    return await _db!.insert('categories', category.toJson());
  }

  @override
  Future<void> updateCategory(GameCategory category) async {
    await _db!.update(
      'categories',
      category.toJson(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> deleteCategory(int id) async {
    await _db!.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- ITEMS ---
  @override
  Future<List<GameItem>> getItemsByCategory(int categoryId) async {
    final maps = await _db!.query('items', where: 'categoryId = ?', whereArgs: [categoryId]);
    return maps.map((json) => GameItem.fromJson(json)).toList();
  }

  @override
  Future<int> insertItem(GameItem item) async {
    return await _db!.insert('items', item.toJson());
  }

  @override
  Future<void> updateItem(GameItem item) async {
    await _db!.update(
      'items',
      item.toJson(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> deleteItem(int id) async {
    await _db!.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // --- BACKUP & RESTORE ---
  @override
  Future<String> exportDatabaseToJson() async {
    final categories = await _db!.query('categories');
    final items = await _db!.query('items');
    
    final backupData = {
      'categories': categories,
      'items': items,
    };
    return jsonEncode(backupData);
  }

  @override
  Future<void> importDatabaseFromJson(String jsonData) async {
    final Map<String, dynamic> backupData = jsonDecode(jsonData);
    final categories = backupData['categories'] as List;
    final items = backupData['items'] as List;

    await _db!.transaction((txn) async {
      // Clear existing data
      await txn.delete('items');
      await txn.delete('categories');

      // Insert restored data
      for (var cat in categories) {
        await txn.insert('categories', cat as Map<String, Object?>);
      }
      for (var item in items) {
        await txn.insert('items', item as Map<String, Object?>);
      }
    });
  }
}
