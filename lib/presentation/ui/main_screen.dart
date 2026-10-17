import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase_data_source.dart';
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
  String? _lastShownNotice;

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final syncStatusAsync = ref.watch(hybridSyncStatusProvider);
    final syncStatus = syncStatusAsync.value ?? const HybridSyncStatus();

    ref.listen<AsyncValue<HybridSyncStatus>>(hybridSyncStatusProvider, (prev, next) {
      final status = next.value;
      if (status == null) return;
      final msg = status.noticeMessage;
      if (msg != null && msg.isNotEmpty && msg != _lastShownNotice) {
        _lastShownNotice = msg;
        if (!mounted) return;
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              backgroundColor: status.isOfflineAlert
                  ? scheme.errorContainer
                  : scheme.secondaryContainer,
              content: Row(
                children: [
                  Icon(
                    status.isOfflineAlert
                        ? Icons.cloud_off_outlined
                        : (status.isSyncing ? Icons.sync : Icons.cloud_done_outlined),
                    color: status.isOfflineAlert
                        ? scheme.onErrorContainer
                        : scheme.onSecondaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      msg,
                      style: TextStyle(
                        color: status.isOfflineAlert
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              action: status.isOfflineAlert
                  ? SnackBarAction(
                      label: 'Coba Sync',
                      textColor: scheme.onErrorContainer,
                      onPressed: () {
                        ref
                            .read(hybridDataSourceProvider)
                            .checkConnectionAndSync(manual: true);
                      },
                    )
                  : null,
            ),
          );
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          selectedCategory.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          _HybridStatusChip(
            status: syncStatus,
            onTap: () async {
              final ok = await ref
                  .read(hybridDataSourceProvider)
                  .checkConnectionAndSync(manual: true);
              if (ok) {
                ref.invalidate(allEntriesProvider);
                for (final c in EntryCategory.values) {
                  ref.invalidate(entriesProvider(c));
                }
              }
            },
          ),
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
          // --- BANNER MODE OFFLINE / PROSES SINKRONISASI ---
          if (!syncStatus.isOnline || syncStatus.isSyncing || syncStatus.pendingCount > 0)
            _HybridSyncBanner(
              status: syncStatus,
              onRetrySync: () async {
                final ok = await ref
                    .read(hybridDataSourceProvider)
                    .checkConnectionAndSync(manual: true);
                if (ok) {
                  ref.invalidate(allEntriesProvider);
                  for (final c in EntryCategory.values) {
                    ref.invalidate(entriesProvider(c));
                  }
                }
              },
            ),

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

class _HybridStatusChip extends StatelessWidget {
  final HybridSyncStatus status;
  final VoidCallback onTap;

  const _HybridStatusChip({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = status.isOnline;
    final isSyncing = status.isSyncing;
    final pending = status.pendingCount;

    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String label;

    if (isSyncing) {
      bgColor = theme.colorScheme.secondaryContainer;
      fgColor = theme.colorScheme.onSecondaryContainer;
      icon = Icons.sync;
      label = 'Syncing...';
    } else if (!isOnline) {
      bgColor = Colors.orange.withValues(alpha: 0.2);
      fgColor = Colors.orangeAccent;
      icon = Icons.cloud_off_outlined;
      label = pending > 0 ? 'SQLite ($pending)' : 'SQLite Offline';
    } else if (pending > 0) {
      bgColor = theme.colorScheme.tertiaryContainer;
      fgColor = theme.colorScheme.onTertiaryContainer;
      icon = Icons.cloud_upload_outlined;
      label = 'Sync ($pending)';
    } else {
      bgColor = Colors.green.withValues(alpha: 0.18);
      fgColor = Colors.greenAccent;
      icon = Icons.cloud_done_outlined;
      label = 'Hybrid Sync';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fgColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fgColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HybridSyncBanner extends StatelessWidget {
  final HybridSyncStatus status;
  final VoidCallback onRetrySync;

  const _HybridSyncBanner({required this.status, required this.onRetrySync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOffline = !status.isOnline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOffline
            ? Colors.orange.withValues(alpha: 0.14)
            : scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOffline ? Colors.orangeAccent.withValues(alpha: 0.5) : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            status.isSyncing
                ? Icons.sync
                : (isOffline ? Icons.storage_rounded : Icons.cloud_upload_outlined),
            size: 18,
            color: isOffline ? Colors.orangeAccent : scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.isSyncing
                  ? 'Menyinkronkan data SQLite lokal ke PostgreSQL Supabase...'
                  : isOffline
                      ? 'Mode Offline Aktif: Semua perubahan disimpan cepat di SQLite lokal${status.pendingCount > 0 ? ' (${status.pendingCount} menunggu sync)' : ''} & otomatis disinkronkan saat internet terhubung.'
                      : '${status.pendingCount} data lokal siap disinkronkan ke Supabase PostgreSQL.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOffline ? Colors.orangeAccent : scheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!status.isSyncing)
            TextButton(
              onPressed: onRetrySync,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Sync'),
            ),
        ],
      ),
    );
  }
}