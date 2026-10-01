import '../../domain/entities/game_category.dart';
import '../../domain/entities/game_item.dart';
import '../../domain/repositories/game_repository.dart';
import '../datasources/local_data_source.dart';

class GameRepositoryImpl implements GameRepository {
  final LocalDataSource localDataSource;
  // If you add an API later: final RemoteDataSource remoteDataSource;

  GameRepositoryImpl({required this.localDataSource});

  @override
  Future<List<GameCategory>> fetchCategories() => localDataSource.getCategories();

  @override
  Future<void> addCategory(GameCategory category) => localDataSource.insertCategory(category);

  @override
  Future<void> editCategory(GameCategory category) => localDataSource.updateCategory(category);

  @override
  Future<void> removeCategory(int id) => localDataSource.deleteCategory(id);

  @override
  Future<List<GameItem>> fetchItems(int categoryId) => localDataSource.getItemsByCategory(categoryId);

  @override
  Future<void> addItem(GameItem item) => localDataSource.insertItem(item);

  @override
  Future<void> editItem(GameItem item) => localDataSource.updateItem(item);

  @override
  Future<void> removeItem(int id) => localDataSource.deleteItem(id);

  @override
  Future<String> exportData() => localDataSource.exportDatabaseToJson();

  @override
  Future<void> importData(String jsonData) => localDataSource.importDatabaseFromJson(jsonData);
}
