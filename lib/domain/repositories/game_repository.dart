import '../entities/game_category.dart';
import '../entities/game_item.dart';

/// Abstract Repository.
/// The UI/Riverpod providers will ONLY interact with this interface.
abstract class GameRepository {
  Future<List<GameCategory>> fetchCategories();
  Future<void> addCategory(GameCategory category);
  Future<void> editCategory(GameCategory category);
  Future<void> removeCategory(int id);

  Future<List<GameItem>> fetchItems(int categoryId);
  Future<void> addItem(GameItem item);
  Future<void> editItem(GameItem item);
  Future<void> removeItem(int id);

  Future<String> exportData();
  Future<void> importData(String jsonData);
}
