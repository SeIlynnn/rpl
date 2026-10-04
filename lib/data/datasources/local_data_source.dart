import '../../domain/entities/entry_category.dart';

/// Abstract Local Data Source. 
/// If you ever switch from sqflite to Isar or Hive, you only implement this interface.
abstract class LocalDataSource {
  Future<void> initDb();

  /// `true` when none of the encyclopedia tables contain a single row.
  Future<bool> isEmpty();

  /// Inserts many rows per table inside one transaction (used for seeding).
  Future<void> bulkInsert(Map<EntryCategory, List<Map<String, Object?>>> rowsByCategory);

  // Entries (materials / armors / monsters)
  Future<List<Map<String, Object?>>> getAll(EntryCategory category);
  Future<int> insert(EntryCategory category, Map<String, Object?> row);
  Future<void> update(EntryCategory category, int id, Map<String, Object?> row);
  Future<void> delete(EntryCategory category, int id);
  
  // Backup
  Future<String> exportDatabaseToJson();
  Future<void> importDatabaseFromJson(String jsonData);
}
