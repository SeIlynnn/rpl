import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';
import '../../domain/entities/monster.dart';
import '../../domain/entities/game_material.dart';
import '../../domain/entities/weapon.dart';
import '../../domain/entities/armor.dart';
import '../../domain/entities/charm.dart';
import '../providers/game_providers.dart';
import '../../domain/entities/animal.dart';
import '../../domain/entities/game_map.dart';
import 'category_ui.dart';
import 'entry_actions.dart';
import 'entry_widgets.dart';

/// Menampilkan daftar entri untuk satu kategori.
/// Jika ada kata kunci pencarian global, cari di SEMUA kategori.
class ItemListView extends ConsumerWidget {
  final EntryCategory category;

  const ItemListView({super.key, required this.category});

  // Logika pencarian yang mencakup banyak field
  bool _matches(EncyclopediaEntry entry, String query) {
    if (query.isEmpty) return false;
    final itemId = entryItemId(entry);
    final haystack = [
      entry.name,
      if (itemId != null) 'id:$itemId #$itemId $itemId',
      entry.category.singular,
      entry.category.label,
      if (entry is Monster) ...[entry.classification, entry.habitat, entry.title, entry.itemDrop],
      if (entry is GameMaterial) ...[entry.itemType, entry.itemDrop, entry.objectDrop],
      if (entry is Animal) ...[entry.habitat, entry.itemDrop, '${entry.totalHp}'],
      if (entry is Weapon) ...[entry.role, entry.normalStats, entry.negativeStats, entry.skillAktif],
      if (entry is Armor) ...[entry.type, entry.stats, entry.skill],
      if (entry is Charm) ...[entry.stats],
      if (entry is GameMap) ...[entry.deskripsi],
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(query);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pantau kata kunci pencarian dari provider global
    final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
    // Ambil semua data dari semua kategori
    final allEntriesAsync = ref.watch(allEntriesProvider);

    return allEntriesAsync.when(
      data: (allEntries) {
        // LOGIKA UTAMA:
        // - Jika search kosong -> Tampilkan hanya kategori saat ini
        // - Jika search ada isinya -> Cari di SEMUA kategori
        final visible = searchQuery.isEmpty
            ? allEntries.where((e) => e.category == category).toList()
            : allEntries.where((e) => _matches(e, searchQuery)).toList();

        if (visible.isEmpty) {
          return _EmptyState(
            category: category,
            isSearching: searchQuery.isNotEmpty,
          );
        }

        return ListView.separated(
          key: PageStorageKey('list-${category.name}'),
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 88),
          itemBuilder: (context, index) {
            final entry = visible[index];
            // Tampilkan label kategori jika hasil pencarian dari kategori berbeda
            final showCategory = searchQuery.isNotEmpty && entry.category != category;
            return _EntryTile(entry: entry, showCategory: showCategory);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        debugPrint('Load failed: $err\n$stack');
        return _ErrorState(
          message: 'Terjadi kesalahan saat memuat data. Silakan coba lagi.',
          onRetry: () => ref.invalidate(repositoryProvider),
        );
      },
    );
  }
}

class _EntryTile extends ConsumerWidget {
  final EncyclopediaEntry entry;
  final bool showCategory;

  const _EntryTile({required this.entry, this.showCategory = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rarity = entryRarity(entry);
    final itemId = entryItemId(entry);
    final subtitle = entrySubtitle(entry);
    final entry0 = entry;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Hero(
        tag: 'entry-image-${entry.category.name}-${entry.id}',
        child: EntryImage(
          path: entry.imagePath,
          placeholderIcon: entry.category.icon,
          width: 56,
          height: 56,
          iconSize: 26,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName(entry.name),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (itemId != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ID $itemId',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
        showCategory
            ? '${entry.category.label} · $subtitle'
            : subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: rarity != null
          ? RarityBadge(rarity: rarity, dense: true)
          : entry0 is Monster && entry0.no != null
          ? Text(
        '#${entry0.no}',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.outline,
        ),
      )
          : entry0 is GameMap
          ? Icon(
              entry0.imagePath != null ? Icons.photo_library_outlined : Icons.chevron_right,
              color: theme.colorScheme.outline,
            )
          : null,
      onTap: () => openEntryDetail(context, entry),
      onLongPress: () => showEntryActionsSheet(context, ref, entry),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final EntryCategory category;
  final bool isSearching;

  const _EmptyState({required this.category, required this.isSearching});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : category.icon,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? 'No results found across all categories.'
                : 'No ${category.label.toLowerCase()} yet.\nTap "Add ${category.singular}" to create one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('Could not load the database',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}