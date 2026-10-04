import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entry_category.dart';
import '../providers/game_providers.dart';
import 'category_ui.dart';

class CategoryDrawer extends ConsumerWidget {
  const CategoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final theme = Theme.of(context);

    final counts = <EntryCategory, int?>{
      for (final cat in EntryCategory.values)
        cat: ref.watch(entriesProvider(cat)).value?.length,
    };

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_stories,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frontier Lands',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Encyclopedia & DB',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CATEGORIES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final category in EntryCategory.values) ...[
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      selected: category == selectedCategory,
                      selectedTileColor: theme.colorScheme.secondaryContainer,
                      selectedColor: theme.colorScheme.onSecondaryContainer,
                      leading: Icon(
                        category == selectedCategory
                            ? category.selectedIcon
                            : category.icon,
                        color: category == selectedCategory
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        category.label,
                        style: TextStyle(
                          fontWeight: category == selectedCategory
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: counts[category] != null
                          ? Badge(
                              label: Text('${counts[category]}'),
                              backgroundColor: category == selectedCategory
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              textColor: category == selectedCategory
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            )
                          : null,
                      onTap: () {
                        ref.read(selectedCategoryProvider.notifier).select(category);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.storage_outlined,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SQLite Seeded Database',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
