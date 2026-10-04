import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/entry_category.dart';
import 'local_data_source.dart';

class SqfliteDataSource implements LocalDataSource {
  static const _dbName = 'companion_app.db';

  /// v1 = generic prototype (categories/items), v2 = Frontier Lands encyclopedia.
  static const _dbVersion = 2;

  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('SqfliteDataSource.initDb() must be called first.');
    }
    return db;
  }

  @override
  Future<void> initDb() async {
    if (_db != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) => _createEncyclopediaTables(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: introduce the encyclopedia tables. The legacy prototype
        // tables (categories/items) are intentionally left untouched so no
        // user data is destroyed by the upgrade.
        if (oldVersion < 2) await _createEncyclopediaTables(db);
      },
    );
  }

  /// Column names match the keys of `assets/seed_data.json` 1:1.
  /// `"no"`, `"type"` and `"def"` are quoted because they are SQL keywords.
  Future<void> _createEncyclopediaTables(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE IF NOT EXISTS materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER NOT NULL,
        nama_item TEXT NOT NULL,
        rarity INTEGER,
        item_type TEXT,
        item_drop TEXT,
        persentase REAL,
        image_path TEXT
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS armors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER NOT NULL,
        nama_item TEXT NOT NULL,
        rarity INTEGER,
        "type" TEXT,
        stats TEXT,
        skill TEXT,
        image_path TEXT
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS monsters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER NOT NULL,
        nama TEXT NOT NULL,
        title TEXT,
        habitat TEXT,
        classification TEXT,
        imun_to TEXT,
        item_drop TEXT,
        max_health TEXT,
        "def" TEXT,
        size TEXT,
        image_path TEXT
      )
    ''');
    await batch.commit(noResult: true);
  }

  @override
  Future<bool> isEmpty() async {
    for (final category in EntryCategory.values) {
      final count = Sqflite.firstIntValue(
        await _database.rawQuery('SELECT COUNT(*) FROM ${category.tableName}'),
      );
      if ((count ?? 0) > 0) return false;
    }
    return true;
  }

  @override
  Future<void> bulkInsert(Map<EntryCategory, List<Map<String, Object?>>> rowsByCategory) async {
    await _database.transaction((txn) async {
      final batch = txn.batch();
      rowsByCategory.forEach((category, rows) {
        for (final row in rows) {
          batch.insert(category.tableName, row);
        }
      });
      await batch.commit(noResult: true);
    });
  }

  // --- ENTRIES ---
  @override
  Future<List<Map<String, Object?>>> getAll(EntryCategory category) {
    return _database.query(category.tableName, orderBy: '"no" ASC, id ASC');
  }

  @override
  Future<int> insert(EntryCategory category, Map<String, Object?> row) {
    return _database.insert(category.tableName, row);
  }

  @override
  Future<void> update(EntryCategory category, int id, Map<String, Object?> row) async {
    await _database.update(
      category.tableName,
      Map.of(row)..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> delete(EntryCategory category, int id) async {
    await _database.delete(category.tableName, where: 'id = ?', whereArgs: [id]);
  }

  // --- BACKUP & RESTORE ---
  @override
  Future<String> exportDatabaseToJson() async {
    final backupData = <String, Object?>{
      for (final category in EntryCategory.values)
        category.tableName: await _database.query(category.tableName),
    };
    return jsonEncode(backupData);
  }

  @override
  Future<void> importDatabaseFromJson(String jsonData) async {
    final Map<String, dynamic> backupData = jsonDecode(jsonData);

    await _database.transaction((txn) async {
      for (final category in EntryCategory.values) {
        final rows = backupData[category.tableName] as List? ?? const [];
        // Clear existing data, then insert restored data
        await txn.delete(category.tableName);
        for (final row in rows) {
          await txn.insert(category.tableName, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }
}
