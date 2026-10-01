import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'category_drawer.dart';
import 'item_list_view.dart';
import 'item_form_screen.dart';
import '../providers/game_providers.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedCategory?.name ?? 'Game Database'),
        centerTitle: true,
      ),
      drawer: const CategoryDrawer(),
      body: selectedCategory == null 
          ? const Center(
              child: Text(
                '⬅️ Open the menu to select\nor create a category.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              )
            )
          : const ItemListView(),
      
      // Floating Action Button to add items directly to the selected category
      floatingActionButton: selectedCategory == null ? null : FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => ItemFormScreen(categoryId: selectedCategory.id!)
            )
          );
        },
        icon: const Icon(Icons.add),
        label: Text('Add ${selectedCategory.name}'),
      ),
    );
  }
}
