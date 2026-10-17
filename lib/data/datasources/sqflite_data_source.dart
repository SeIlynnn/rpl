import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/entry_category.dart';
import 'local_data_source.dart';

class SqfliteDataSource implements LocalDataSource {
  static const _dbName = 'companion_app.db';

  /// v1 = generic prototype, v2 = Frontier Lands, v3 = weapons & charms,
  /// v4 = updated weapon stats, v5 = rarity for all categories,
  /// v8 = clean Rules Book Frontier Lands Excel seed data (no hallucinations),
  /// v9 = maps table + monster item_id + relational sync support,
  /// v10 = hybrid offline sync_queue + customizable field_presets.
  static const _dbVersion = 10;

  static const Map<String, List<String>> defaultFieldPresets = {
    'materials.item_drop': ['Boss', 'monster kecil', 'hewan', 'Tumbuhan', 'Pohon', 'Rock'],
    'materials.item_type': ['Material', 'Consumable', 'Key Item'],
    'armors.type': ['Armor'],
    'weapons.role': ['Tenk', 'Mele', 'Range', 'Support'],
    'monsters.classification': [
      'Small Monster',
      'Karapas',
      'Fang Beast',
      'Abysal',
      'Ancient Beast',
      'Umbra Beast',
      'Flying Beast',
      'Artificial Being',
    ],
    'monsters.size': ['small', 'medium', 'Large', 'Gargantua'],
    'monsters.imun_to': ['Burning', 'Poison', 'Paralyze', 'Knockback'],
  };

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
        if (oldVersion < 8) {
          final batch = db.batch();
          for (final category in EntryCategory.values) {
            batch.execute('DROP TABLE IF EXISTS ${category.tableName}');
          }
          await batch.commit(noResult: true);
        } else if (oldVersion < 9) {
          try {
            await db.execute('ALTER TABLE monsters ADD COLUMN item_id INTEGER');
          } catch (_) {}
        }
        await _createEncyclopediaTables(db);
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

    // --- MONSTERS ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS monsters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER,
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

    // --- ANIMALS ---
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

    // --- MAPS (Habitat / World Maps) ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS maps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        "no" INTEGER,
        item_id INTEGER,
        nama TEXT NOT NULL,
        deskripsi TEXT,
        image_path TEXT
      )
    ''');

    // --- HYBRID OFFLINE SYNC QUEUE ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        action TEXT NOT NULL,
        record_id INTEGER,
        payload TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // --- CUSTOMIZABLE FIELD SUGGESTIONS / PRESETS ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS field_presets (
        preset_key TEXT NOT NULL,
        preset_value TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (preset_key, preset_value)
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
          batch.insert(
            category.tableName,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
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
    return _database.insert(
      category.tableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  // --- Preset Suggestions Management ---
  @override
  Future<List<String>> getPresets(String presetKey) async {
    final defaults = List<String>.from(defaultFieldPresets[presetKey] ?? const []);
    final rows = await _database.query(
      'field_presets',
      where: 'preset_key = ?',
      whereArgs: [presetKey],
    );

    final deletedLower = <String>{};
    final addedValues = <String>[];

    for (final row in rows) {
      final val = (row['preset_value'] as String?)?.trim() ?? '';
      if (val.isEmpty) continue;
      final isDeleted = (row['is_deleted'] as int? ?? 0) == 1;
      if (isDeleted) {
        deletedLower.add(val.toLowerCase());
      } else {
        addedValues.add(val);
      }
    }

    final result = <String>[];
    final seenLower = <String>{};

    for (final d in defaults) {
      final lower = d.toLowerCase();
      if (!deletedLower.contains(lower) && seenLower.add(lower)) {
        result.add(d);
      }
    }
    for (final a in addedValues) {
      final lower = a.toLowerCase();
      if (!deletedLower.contains(lower) && seenLower.add(lower)) {
        result.add(a);
      }
    }
    return result;
  }

  @override
  Future<void> addPreset(String presetKey, String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    await _database.insert(
      'field_presets',
      {
        'preset_key': presetKey,
        'preset_value': clean,
        'is_deleted': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removePreset(String presetKey, String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    // Remove case-insensitive match first, then store tombstoned entry so default presets stay removed
    await _database.delete(
      'field_presets',
      where: 'preset_key = ? AND LOWER(preset_value) = ?',
      whereArgs: [presetKey, clean.toLowerCase()],
    );
    await _database.insert(
      'field_presets',
      {
        'preset_key': presetKey,
        'preset_value': clean,
        'is_deleted': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Offline Sync Queue Helpers ---
  Future<void> enqueueSync(
    String tableName,
    String action, {
    int? recordId,
    Map<String, Object?>? payload,
  }) async {
    await _database.insert('sync_queue', {
      'table_name': tableName,
      'action': action,
      'record_id': recordId,
      'payload': payload == null ? null : jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, Object?>>> getSyncQueue() async {
    return _database.query('sync_queue', orderBy: 'id ASC');
  }

  Future<void> removeSyncQueueItem(int queueId) async {
    await _database.delete('sync_queue', where: 'id = ?', whereArgs: [queueId]);
  }

  @override
  Future<int> getPendingSyncCount() async {
    final count = Sqflite.firstIntValue(
      await _database.rawQuery('SELECT COUNT(*) FROM sync_queue'),
    );
    return count ?? 0;
  }

  @override
  Future<bool> syncPendingChanges() async => true;
}