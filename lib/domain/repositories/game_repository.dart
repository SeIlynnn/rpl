import '../entities/encyclopedia_entry.dart';
import '../entities/entry_category.dart';

abstract class GameRepository {
  Future<void> initialize();
  Future<List<EncyclopediaEntry>> fetchEntries(EntryCategory category);
  Future<int> addEntry(EncyclopediaEntry entry);
  Future<void> editEntry(EncyclopediaEntry entry);
  Future<void> removeEntry(EntryCategory category, int id);
  Future<String> exportData();
  Future<void> importData(String jsonData);
}