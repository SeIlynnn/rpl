import '../entities/encyclopedia_entry.dart';
import '../entities/entry_category.dart';

/// Domain-level contract for the Frontier Lands encyclopedia.
abstract class GameRepository {
  /// Opens the database and seeds it from `assets/seed_data.json` when empty.
  Future<void> initialize();

  Future<List<EncyclopediaEntry>> fetchEntries(EntryCategory category);
  Future<int> addEntry(EncyclopediaEntry entry);
  Future<void> editEntry(EncyclopediaEntry entry);
  Future<void> removeEntry(EntryCategory category, int id);

  // Backup
  Future<String> exportData();
  Future<void> importData(String jsonData);
}
