import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';
import '../providers/game_providers.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';

void openEntryDetail(BuildContext context, EncyclopediaEntry entry) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ItemDetailScreen(
        category: entry.category,
        entryId: entry.id!,
      ),
    ),
  );
}

void openEntryForm(BuildContext context, EntryCategory category, {EncyclopediaEntry? existing}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ItemFormScreen(category: category, existingEntry: existing),
    ),
  );
}

Future<void> confirmAndDeleteEntry(BuildContext context, WidgetRef ref, EncyclopediaEntry entry, {bool closeRoute = false}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Entry?'),
      content: Text('Are you sure you want to delete "${entry.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );

  if (confirm == true) {
    final notifier = ref.read(entriesProvider(entry.category).notifier);
    await notifier.removeEntry(entry);
    if (closeRoute && context.mounted) Navigator.pop(context);
  }
}

void showEntryActionsSheet(BuildContext context, WidgetRef ref, EncyclopediaEntry entry) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(ctx);
              openEntryForm(context, entry.category, existing: entry);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              confirmAndDeleteEntry(context, ref, entry);
            },
          ),
        ],
      ),
    ),
  );
}