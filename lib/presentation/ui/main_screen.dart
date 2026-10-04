import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entry_category.dart';
import '../providers/game_providers.dart';
import 'category_drawer.dart';
import 'category_ui.dart';
import 'entry_actions.dart';
import 'item_list_view.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
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
      drawer: const CategoryDrawer(),
      body: IndexedStack(
        index: selectedCategory.index,
        children: const [
          ItemListView(category: EntryCategory.materials),
          ItemListView(category: EntryCategory.armors),
          ItemListView(category: EntryCategory.monsters),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedCategory.index,
        onDestinationSelected: (index) {
          final category = EntryCategory.values[index];
          ref.read(selectedCategoryProvider.notifier).select(category);
        },
        destinations: [
          for (final category in EntryCategory.values)
            NavigationDestination(
              icon: Icon(category.icon),
              selectedIcon: Icon(category.selectedIcon),
              label: category.label,
            ),
        ],
      ),
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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.auto_stories,
          color: theme.colorScheme.primary,
          size: 36,
        ),
        title: const Text('Frontier Lands DB'),
        content: Column(
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
            _StatItem(label: 'Large Monsters', count: monstersCount),
          ],
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
