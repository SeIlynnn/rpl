import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local_data_source.dart';
import '../../data/datasources/supabase_data_source.dart';
import '../../data/repositories/game_repository_impl.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';

const seedAssetPath = 'assets/seed_data.json';

// --- Core Database Providers ---
final hybridDataSourceProvider = Provider<SupabaseDataSource>((ref) {
  return SupabaseDataSource();
});

final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  return ref.watch(hybridDataSourceProvider);
});

/// Live stream of Hybrid Database status (Online PostgreSQL vs Offline SQLite + Sync Queue).
final hybridSyncStatusProvider = StreamProvider<HybridSyncStatus>((ref) async* {
  final ds = ref.watch(hybridDataSourceProvider);
  yield ds.currentStatus;
  await for (final status in ds.statusStream) {
    yield status;
  }
});

/// Opens SQLite and seeds it from [seedAssetPath] on first launch.
final repositoryProvider = FutureProvider<GameRepository>((ref) async {
  final repository = GameRepositoryImpl(
    localDataSource: ref.watch(localDataSourceProvider),
    seedLoader: () => rootBundle.loadString(seedAssetPath),
  );
  await repository.initialize();
  return repository;
});

// --- Entries State Management (one list per category) ---
class EntriesNotifier extends AsyncNotifier<List<EncyclopediaEntry>> {
  final EntryCategory category;
  EntriesNotifier(this.category);

  @override
  Future<List<EncyclopediaEntry>> build() async {
    final repo = await ref.watch(repositoryProvider.future);
    return repo.fetchEntries(category);
  }

  Future<void> addEntry(EncyclopediaEntry entry) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.addEntry(entry);
    ref.invalidateSelf();
    ref.invalidate(allEntriesProvider);
    await future;
  }

  Future<void> updateEntry(EncyclopediaEntry entry) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.editEntry(entry);
    ref.invalidateSelf();
    ref.invalidate(allEntriesProvider);
    await future;
  }

  Future<void> removeEntry(EncyclopediaEntry entry) async {
    final id = entry.id;
    if (id == null) return;
    final repo = await ref.read(repositoryProvider.future);
    await repo.removeEntry(entry.category, id);
    ref.invalidateSelf();
    ref.invalidate(allEntriesProvider);
    await future;
  }
}

final entriesProvider = AsyncNotifierProvider.family<EntriesNotifier,
    List<EncyclopediaEntry>, EntryCategory>(EntriesNotifier.new);

// --- Customizable Field / Category Suggestions (Add & Delete Presets) ---
class FieldPresetsNotifier extends AsyncNotifier<List<String>> {
  final String presetKey;
  FieldPresetsNotifier(this.presetKey);

  @override
  Future<List<String>> build() async {
    final repo = await ref.watch(repositoryProvider.future);
    return repo.getPresets(presetKey);
  }

  Future<void> addPreset(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final repo = await ref.read(repositoryProvider.future);
    await repo.addPreset(presetKey, clean);
    ref.invalidateSelf();
    await future;
  }

  Future<void> removePreset(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final repo = await ref.read(repositoryProvider.future);
    await repo.removePreset(presetKey, clean);
    ref.invalidateSelf();
    await future;
  }
}

final fieldPresetsProvider = AsyncNotifierProvider.family<FieldPresetsNotifier,
    List<String>, String>(FieldPresetsNotifier.new);

// --- Provider untuk Pencarian Global (Semua Kategori) ---
final allEntriesProvider = FutureProvider<List<EncyclopediaEntry>>((ref) async {
  final repo = await ref.watch(repositoryProvider.future);
  final List<EncyclopediaEntry> allEntries = [];

  for (final category in EntryCategory.values) {
    final entries = await repo.fetchEntries(category);
    allEntries.addAll(entries);
  }

  return allEntries;
});

// --- UI State Provider (selected bottom navigation tab) ---
class SelectedCategoryNotifier extends Notifier<EntryCategory> {
  @override
  EntryCategory build() => EntryCategory.materials;

  void select(EntryCategory category) => state = category;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, EntryCategory>(
        SelectedCategoryNotifier.new);

// --- UI State Provider (Global Search Query) ---
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);