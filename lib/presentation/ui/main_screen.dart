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
            tooltip: 'Maps Overview',
            icon: Icon(
              selectedCategory == EntryCategory.maps ? Icons.map : Icons.map_outlined,
            ),
            onPressed: () => ref
                .read(selectedCategoryProvider.notifier)
                .select(EntryCategory.maps),
          ),
          IconButton(
            tooltip: 'About Database',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context, ref),
          ),
        ],
      ),
      drawer: const CategoryDrawer(),
      body: Column(
        children: [
          // --- SEARCH BAR GLOBAL (Berlaku di semua kategori) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              hintText: 'Search Database (Name, ID, Drop, Map...)',
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
                ItemListView(category: EntryCategory.maps),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ModernBottomNavBar(
        selectedCategory: selectedCategory,
        onSelect: (category) =>
            ref.read(selectedCategoryProvider.notifier).select(category),
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
    final weaponsCount =
        ref.read(entriesProvider(EntryCategory.weapons)).value?.length ?? 0;
    final charmsCount =
        ref.read(entriesProvider(EntryCategory.charms)).value?.length ?? 0;
    final animalsCount =
        ref.read(entriesProvider(EntryCategory.animals)).value?.length ?? 0;
    final mapsCount =
        ref.read(entriesProvider(EntryCategory.maps)).value?.length ?? 0;

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
              const Text('A structured Game Encyclopedia with interactive relational sync.'),
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
              _StatItem(label: 'Animals', count: animalsCount),
              _StatItem(label: 'Maps', count: mapsCount),
              const Divider(height: 24),
              _StatItem(
                label: 'Total Entries',
                count: materialsCount +
                    armorsCount +
                    monstersCount +
                    weaponsCount +
                    charmsCount +
                    animalsCount +
                    mapsCount,
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

class _ModernBottomNavBar extends StatelessWidget {
  final EntryCategory selectedCategory;
  final ValueChanged<EntryCategory> onSelect;

  const _ModernBottomNavBar({
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const categories = EntryCategory.values;
              final itemWidth = (constraints.maxWidth / categories.length).clamp(64.0, 140.0);
              final needsScroll = itemWidth * categories.length > constraints.maxWidth + 1;

              final children = [
                for (final cat in categories)
                  SizedBox(
                    width: needsScroll ? 74 : constraints.maxWidth / categories.length,
                    child: _BottomNavItem(
                      category: cat,
                      selected: cat == selectedCategory,
                      onTap: () => onSelect(cat),
                    ),
                  ),
              ];

              if (needsScroll) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: children),
                );
              }
              return Row(children: children);
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final EntryCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? scheme.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? category.selectedIcon : category.icon,
                size: 22,
                color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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