import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entry_category.dart';
import '../providers/game_providers.dart';
import 'category_drawer.dart';
import 'category_ui.dart';
import 'entry_actions.dart';
import 'item_list_view.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Membuka Drawer secara otomatis saat aplikasi pertama kali dijalankan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openDrawer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          selectedCategory.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'About Database',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context, ref),
          ),
        ],
      ),
      drawer: const CategoryDrawer(), // Menu Drawer tetap ada
      body: Column(
        children: [
          // --- SEARCH BAR GLOBAL (Berlaku di semua kategori) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              hintText: 'Search Database',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              trailing: [
                if (searchQuery.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        ref.read(searchQueryProvider.notifier).clear(),
                  ),
              ],
              onChanged: (value) => ref
                  .read(searchQueryProvider.notifier)
                  .updateQuery(value.trim()),
            ),
          ),

          // --- DAFTAR KONTEN ---
          Expanded(
            child: IndexedStack(
              index: selectedCategory.index,
              children: const [
                ItemListView(category: EntryCategory.materials),
                ItemListView(category: EntryCategory.armors),
                ItemListView(category: EntryCategory.monsters),
                ItemListView(category: EntryCategory.weapons),
                ItemListView(category: EntryCategory.charms),
                ItemListView(category: EntryCategory.animals),
              ],
            ),
          ),
        ],
      ),
      // bottomNavigationBar: DIHAPUS sesuai permintaan

      // Tombol + Add tetap dipertahankan
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'main-fab',
        onPressed: () => openEntryForm(context, selectedCategory),
        icon: const Icon(Icons.add),
        label: Text('Add ${selectedCategory.singular}'),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final materialsCount =
        ref.read(entriesProvider(EntryCategory.materials)).value?.length ?? 0;
    final armorsCount =
        ref.read(entriesProvider(EntryCategory.armors)).value?.length ?? 0;
    final monstersCount =
        ref.read(entriesProvider(EntryCategory.monsters)).value?.length ?? 0;
    final weaponsCount =
        ref.read(entriesProvider(EntryCategory.weapons)).value?.length ?? 0;
    final charmsCount =
        ref.read(entriesProvider(EntryCategory.charms)).value?.length ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.auto_stories,
          color: theme.colorScheme.primary,
          size: 36,
        ),
        title: const Text('Frontier Lands DB'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A structured Game Encyclopedia.'),
              const SizedBox(height: 16),
              Text(
                'Database Statistics:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _StatItem(label: 'Materials', count: materialsCount),
              _StatItem(label: 'Armors', count: armorsCount),
              _StatItem(label: 'Monsters', count: monstersCount),
              _StatItem(label: 'Weapons', count: weaponsCount),
              _StatItem(label: 'Charms', count: charmsCount),
              const Divider(height: 24),
              _StatItem(
                label: 'Total Entries',
                count: materialsCount +
                    armorsCount +
                    monstersCount +
                    weaponsCount +
                    charmsCount,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;

  const _StatItem({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$count entries',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}