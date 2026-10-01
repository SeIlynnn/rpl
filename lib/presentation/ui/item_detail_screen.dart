import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/game_item.dart';
import '../providers/game_providers.dart';
import 'item_form_screen.dart';

class ItemDetailScreen extends ConsumerWidget {
  final GameItem item;
  
  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(
                  builder: (_) => ItemFormScreen(categoryId: item.categoryId, existingItem: item)
                )
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              ref.read(itemsProvider(item.categoryId).notifier).removeItem(item.id!);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item.imagePath != null)
              Image.file(
                File(item.imagePath!), 
                height: 250, 
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(
                    item.description, 
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  
                  // Future extension: Loop through item.stats here and display as rows/tables
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
