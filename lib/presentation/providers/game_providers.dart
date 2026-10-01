import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/datasources/sqflite_data_source.dart';
import '../../data/repositories/game_repository_impl.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/entities/game_category.dart';
import '../../domain/entities/game_item.dart';

// --- Core Database Provider ---
final repositoryProvider = FutureProvider<GameRepository>((ref) async {
  final sqfliteDataSource = SqfliteDataSource();
  await sqfliteDataSource.initDb();
  return GameRepositoryImpl(localDataSource: sqfliteDataSource);
});

// --- Categories State Management ---
class CategoriesNotifier extends AsyncNotifier<List<GameCategory>> {
  @override
  Future<List<GameCategory>> build() async {
    final repo = await ref.watch(repositoryProvider.future);
    return repo.fetchCategories();
  }

  Future<void> addCategory(GameCategory category) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.addCategory(category);
    ref.invalidateSelf();
  }

  Future<void> updateCategory(GameCategory category) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.editCategory(category);
    ref.invalidateSelf();
  }

  Future<void> removeCategory(int id) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.removeCategory(id);
    ref.invalidateSelf();
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<GameCategory>>(
      CategoriesNotifier.new,
    );

// --- Items State Management (Filtered by Category) ---
class ItemsNotifier extends AsyncNotifier<List<GameItem>> {
  final int categoryId;
  ItemsNotifier(this.categoryId);

  @override
  Future<List<GameItem>> build() async {
    final repo = await ref.watch(repositoryProvider.future);
    return repo.fetchItems(categoryId);
  }

  Future<void> addItem(GameItem item) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.addItem(item);
    ref.invalidateSelf();
  }

  Future<void> updateItem(GameItem item) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.editItem(item);
    ref.invalidateSelf();
  }

  Future<void> removeItem(int id) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.removeItem(id);
    ref.invalidateSelf();
  }
}

final itemsProvider =
    AsyncNotifierProvider.family<ItemsNotifier, List<GameItem>, int>(
      ItemsNotifier.new,
    );

// --- UI State Provider ---
final selectedCategoryProvider = StateProvider<GameCategory?>((ref) => null);
