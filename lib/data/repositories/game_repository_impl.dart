import 'dart:convert';
import 'package:flutter/foundation.dart'; // Tambahkan ini untuk debugPrint

import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';
import '../../domain/repositories/game_repository.dart';
import '../datasources/local_data_source.dart';

/// Loads the raw seed JSON (injected so tests can avoid the asset bundle).
typedef SeedLoader = Future<String> Function();

class GameRepositoryImpl implements GameRepository {
  final LocalDataSource localDataSource;
  final SeedLoader seedLoader;
  // If you add an API later: final RemoteDataSource remoteDataSource;

  GameRepositoryImpl({required this.localDataSource, required this.seedLoader});

  @override
  Future<void> initialize() async {
    await localDataSource.initDb();
    if (await localDataSource.isEmpty()) {
      await _seedFromAssets();
    }
  }

  /// Reads `assets/seed_data.json` and bulk-inserts every record.
  /// Each record is round-tripped through its entity so only known columns
  /// reach SQLite and values are normalised to the right types.
  Future<void> _seedFromAssets() async {
    try {
      final String jsonString = await seedLoader();

      // Jika file kosong atau hanya berisi spasi, hentikan proses seeding
      if (jsonString.trim().isEmpty) {
        debugPrint("Seed data kosong, melewati proses seeding.");
        return;
      }

      final Map<String, dynamic> seed = jsonDecode(jsonString);

      final rowsByCategory = <EntryCategory, List<Map<String, Object?>>>{
        for (final category in EntryCategory.values)
          category: [
            for (final record in (seed[category.tableName] as List? ?? const []))
              category.fromMap(Map<String, Object?>.from(record as Map)).toMap(),
          ],
      };

      await localDataSource.bulkInsert(rowsByCategory);
    } catch (e) {
      // Menangkap error jika format JSON salah, agar aplikasi tidak crash
      debugPrint("Gagal membaca atau memproses seed data: $e");
    }
  }

  @override
  Future<List<EncyclopediaEntry>> fetchEntries(EntryCategory category) async {
    final rows = await localDataSource.getAll(category);
    return rows.map(category.fromMap).toList(growable: false);
  }

  @override
  Future<int> addEntry(EncyclopediaEntry entry) =>
      localDataSource.insert(entry.category, entry.toMap());

  @override
  Future<void> editEntry(EncyclopediaEntry entry) {
    final id = entry.id;
    if (id == null) throw ArgumentError('Cannot edit an entry without an id.');
    return localDataSource.update(entry.category, id, entry.toMap());
  }

  @override
  Future<void> removeEntry(EntryCategory category, int id) =>
      localDataSource.delete(category, id);

  @override
  Future<String> exportData() => localDataSource.exportDatabaseToJson();

  @override
  Future<void> importData(String jsonData) => localDataSource.importDatabaseFromJson(jsonData);
}