import '../../domain/entities/game_category.dart';
import '../../domain/entities/game_item.dart';

/// Abstract Local Data Source. 
/// If you ever switch from sqflite to Isar or Hive, you only implement this interface.
abstract class LocalDataSource {
  Future<void> initDb();
  
  // Categories
  Future<List<GameCategory>> getCategories();
  Future<int> insertCategory(GameCategory category);
  Future<void> updateCategory(GameCategory category);
  Future<void> deleteCategory(int id);

  // Items
  Future<List<GameItem>> getItemsByCategory(int categoryId);
  Future<int> insertItem(GameItem item);
  Future<void> updateItem(GameItem item);
  Future<void> deleteItem(int id);
  
  // Backup
  Future<String> exportDatabaseToJson();
  Future<void> importDatabaseFromJson(String jsonData);
}
