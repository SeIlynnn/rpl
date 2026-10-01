import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import '../../domain/entities/game_category.dart';

class CategoryDrawer extends ConsumerWidget {
  const CategoryDrawer({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueGrey),
            child: Center(
              child: Text(
                'Game Database', 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
              )
            ),
          ),
          Expanded(
            child: categoriesAsync.when(
              data: (categories) => ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(cat.name),
                    onTap: () {
                      ref.read(selectedCategoryProvider.notifier).state = cat;
                      Navigator.pop(context); // Close drawer
                    },
                    onLongPress: () => _showEditDeleteDialog(context, ref, cat),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.blueAccent),
            title: const Text('Add Category', style: TextStyle(color: Colors.blueAccent)),
            onTap: () => _showAddDialog(context, ref),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('New Category'),
      content: TextField(
        controller: ctrl, 
        decoration: const InputDecoration(hintText: 'e.g., Weapons, Monsters, Items'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              ref.read(categoriesProvider.notifier).addCategory(GameCategory(name: ctrl.text.trim()));
              Navigator.pop(c);
            }
          }, 
          child: const Text('Add')
        ),
      ]
    ));
  }
  
  void _showEditDeleteDialog(BuildContext context, WidgetRef ref, GameCategory cat) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text('Manage ${cat.name}'),
      content: const Text('Deleting this category will delete all items inside it.'),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(categoriesProvider.notifier).removeCategory(cat.id!);
            if (ref.read(selectedCategoryProvider)?.id == cat.id) {
               ref.read(selectedCategoryProvider.notifier).state = null;
            }
            Navigator.pop(c);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red))
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
      ]
    ));
  }
}
