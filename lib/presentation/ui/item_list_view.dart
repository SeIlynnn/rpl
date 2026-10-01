import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import 'item_detail_screen.dart';

class ItemListView extends ConsumerWidget {
  const ItemListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(selectedCategoryProvider);
    if (category == null || category.id == null) return const SizedBox();

    final itemsAsync = ref.watch(itemsProvider(category.id!));

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No items in ${category.name} yet.\nTap + to add one.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imagePath != null 
                    ? Image.file(File(item.imagePath!), width: 56, height: 56, fit: BoxFit.cover)
                    : Container(
                        width: 56, height: 56, color: Colors.blueGrey.withOpacity(0.3),
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
