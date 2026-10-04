import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';
import '../../domain/entities/monster.dart';
import '../providers/game_providers.dart';
import 'category_ui.dart';
import 'entry_actions.dart';
import 'entry_widgets.dart';

/// Searchable list of every record in one [category].
class ItemListView extends ConsumerStatefulWidget {
  final EntryCategory category;

  const ItemListView({super.key, required this.category});

  @override
  ConsumerState<ItemListView> createState() => _ItemListViewState();
}

class _ItemListViewState extends ConsumerState<ItemListView>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(EncyclopediaEntry entry) {
    if (_query.isEmpty) return true;
    final haystack = [
      entry.name,
      entrySubtitle(entry),
      if (entry is Monster) ...[entry.classification, entry.itemDrop],
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final category = widget.category;
    final entriesAsync = ref.watch(entriesProvider(category));

    return entriesAsync.when(
      data: (entries) {
        final visible = entries.where(_matches).toList(growable: false);
        return CustomScrollView(
          key: PageStorageKey('list-${category.name}'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search ${category.label.toLowerCase()}',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  _query.isEmpty
                      ? '${entries.length} ${category.label.toLowerCase()}'
                      : '${visible.length} of ${entries.length} ${category.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(category: category, isSearching: _query.isNotEmpty),
              )
            else
              SliverPadding(
                // Leaves room so the FAB never hides the last row.
                padding: const EdgeInsets.only(bottom: 96),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 88),
                  itemBuilder: (context, index) => _EntryTile(entry: visible[index]),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => _ErrorState(
        message: '$err',
        onRetry: () => ref.invalidate(repositoryProvider),
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  final EncyclopediaEntry entry;

  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rarity = entryRarity(entry);
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
      title: Text(
        displayName(entry.name),
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: rarity != null
          ? RarityBadge(rarity: rarity, dense: true)
          : entry0 is Monster
              ? Text(
                  '#${entry0.no}',
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
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
          Icon(isSearching ? Icons.search_off : category.icon, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? 'No ${category.label.toLowerCase()} match your search.'
                : 'No ${category.label.toLowerCase()} yet.\nTap "Add ${category.singular}" to create one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            Text('Could not load the database', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
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
