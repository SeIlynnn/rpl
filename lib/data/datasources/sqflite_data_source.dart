import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/entry_category.dart';
import 'local_data_source.dart';

class SqfliteDataSource implements LocalDataSource {
  static const _dbName = 'companion_app.db';

  /// v1 = generic prototype, v2 = Frontier Lands, v3 = weapons & charms,
  /// v4 = updated weapon stats, v5 = rarity for all categories.
  static const _dbVersion = 7;

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
        if (oldVersion < 2) await _createEncyclopediaTables(db);
      },
    );
  }

  Future<void> _createEncyclopediaTables(Database db) async {
    final batch = db.batch();

    // --- MATERIALS (Sudah ada rarity) ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER,
        nama_item TEXT NOT NULL,
        rarity INTEGER,
        item_type TEXT,
        item_drop TEXT,
        object_drop TEXT, 
        persentase REAL,
        image_path TEXT
      )
    ''');

    // --- ARMORS (Sudah ada rarity) ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS armors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER,
        nama_item TEXT NOT NULL,
        rarity INTEGER,
        "type" TEXT,
        stats TEXT,
        skill TEXT,
        image_path TEXT
      )
    ''');

    // --- MONSTERS (Tidak berubah) ---
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

    // --- WEAPONS (Tambahkan rarity) ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS weapons (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER,
        nama_item TEXT NOT NULL,
        rarity INTEGER,
        role TEXT,                
        normal_stats TEXT,
        negative_stats TEXT,
        skill_aktif TEXT,        
        image_path TEXT
      )
    ''');

    // --- CHARMS (Tambahkan rarity) ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS charms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER,
        nama_item TEXT NOT NULL,
        rarity INTEGER,
        stats TEXT,
        image_path TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS animals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER,
        nama TEXT NOT NULL,
        total_hp INTEGER,
        habitat TEXT,
        item_drop TEXT,
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
        await txn.delete(category.tableName);
        for (final row in rows) {
          await txn.insert(category.tableName, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }
}