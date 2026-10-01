import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/game_item.dart';
import '../providers/game_providers.dart';
import '../../core/utils/storage_utils.dart';

class ItemFormScreen extends ConsumerStatefulWidget {
  final int categoryId;
  final GameItem? existingItem;

  const ItemFormScreen({super.key, required this.categoryId, this.existingItem});

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _imagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _titleCtrl.text = widget.existingItem!.title;
      _descCtrl.text = widget.existingItem!.description;
      _imagePath = widget.existingItem!.imagePath;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      // 1. App user picks image from gallery
      // 2. We copy it to the local app documents directory immediately so it persists
      final savedPath = await StorageUtils.persistImageLocally(xfile.path);
      setState(() {
        _imagePath = savedPath;
      });
    }
  }

  void _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);

    final item = GameItem(
      id: widget.existingItem?.id,
      categoryId: widget.categoryId,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      imagePath: _imagePath,
      stats: widget.existingItem?.stats ?? {}, // Persist old stats if any
    );

    if (widget.existingItem == null) {
      await ref.read(itemsProvider(widget.categoryId).notifier).addItem(item);
    } else {
      await ref.read(itemsProvider(widget.categoryId).notifier).updateItem(item);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null ? 'Add Entry' : 'Edit Entry'),
      ),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Image Picker Box
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _imagePath != null 
                      ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                            SizedBox(height: 8),
                            Text("Tap to add custom image", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title / Name', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description / Notes', 
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Entry', style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
    );
  }
}
