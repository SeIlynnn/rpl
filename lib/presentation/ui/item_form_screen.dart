import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/map_parsing.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';
import '../providers/game_providers.dart';
import '../../core/utils/storage_utils.dart';
import 'category_ui.dart';
import 'entry_widgets.dart';

/// Add / Edit form for any category. Fields are generated from
/// [EntryCategoryUi.fields] so every SQLite column is editable.
class ItemFormScreen extends ConsumerStatefulWidget {
  final EntryCategory category;
  final EncyclopediaEntry? existingEntry;

  const ItemFormScreen({super.key, required this.category, this.existingEntry});

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  String? _imagePath;
  String? _originalImagePath;

  /// Images copied into app storage during this session (cleaned up if unused).
  final Set<String> _pickedImages = {};
  bool _isSaving = false;
  bool _saved = false;

  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;
    final values = existing?.toMap() ?? _defaultsForNewEntry();
    _controllers = {
      for (final field in widget.category.fields)
        field.key: TextEditingController(text: _formatForInput(field, values[field.key])),
    };
    _imagePath = existing?.imagePath;
    _originalImagePath = existing?.imagePath;
  }

  /// Pre-fills `no` / `item_id` with the next free number for new records.
  Map<String, Object?> _defaultsForNewEntry() {
    final entries = ref.read(entriesProvider(widget.category)).value ?? const [];
    int nextOf(String key) {
      var max = 0;
      for (final entry in entries) {
        final value = MapParsing.asInt(entry.toMap()[key]) ?? 0;
        if (value > max) max = value;
      }
      return max + 1;
    }

    return {
      for (final field in widget.category.fields)
        if (field.key == 'no' || field.key == 'item_id') field.key: nextOf(field.key),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    // Discarded form: remove images that were copied but never saved.
    if (!_saved) {
      for (final path in _pickedImages) {
        StorageUtils.deleteLocalImage(path);
      }
    }
    super.dispose();
  }

  static String _formatNumber(num value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatForInput(FieldSpec field, Object? value) {
    if (value == null) return '';
    if (field.kind == FieldKind.percent) {
      final fraction = MapParsing.asDouble(value);
      return fraction == null ? '' : _formatNumber(fraction * 100);
    }
    return '$value';
  }

  Object? _parseFromInput(FieldSpec field, String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    return switch (field.kind) {
      FieldKind.integer || FieldKind.rarity => int.tryParse(text),
      FieldKind.percent => (double.tryParse(text.replaceAll(',', '.')) ?? 0) / 100,
      FieldKind.tags => MapParsing.splitTags(text).join(', '),
      _ => text,
    };
  }

  String? _validate(FieldSpec field, String? input) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) return field.required ? '${field.label} is required' : null;
    switch (field.kind) {
      case FieldKind.integer:
        if (int.tryParse(text) == null) return 'Enter a whole number';
      case FieldKind.rarity:
        final rarity = int.tryParse(text);
        if (rarity == null || rarity < 1 || rarity > 10) return 'Rarity must be 1 – 10';
      case FieldKind.percent:
        final percent = double.tryParse(text.replaceAll(',', '.'));
        if (percent == null || percent < 0 || percent > 100) return 'Enter a value between 0 and 100';
      default:
        break;
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      // 1. App user picks image from gallery
      // 2. We copy it to the local app documents directory immediately so it persists
      final savedPath = await StorageUtils.persistImageLocally(xfile.path);
      if (savedPath == null || !mounted) return;
      setState(() {
        _pickedImages.add(savedPath);
        _imagePath = savedPath;
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final map = <String, Object?>{
      'id': widget.existingEntry?.id,
      'image_path': _imagePath,
      for (final field in widget.category.fields)
        field.key: _parseFromInput(field, _controllers[field.key]!.text),
    };
    final entry = widget.category.fromMap(map);
    final notifier = ref.read(entriesProvider(widget.category).notifier);

    try {
      if (_isEditing) {
        await notifier.updateEntry(entry);
      } else {
        await notifier.addEntry(entry);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      return;
    }

    // Clean up images that were replaced or picked but not kept.
    _saved = true;
    for (final path in _pickedImages) {
      if (path != _imagePath) StorageUtils.deleteLocalImage(path);
    }
    if (_originalImagePath != null && _originalImagePath != _imagePath) {
      StorageUtils.deleteLocalImage(_originalImagePath);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing
            ? '${widget.category.singular} updated'
            : '${widget.category.singular} added'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: Icon(_isEditing ? Icons.arrow_back : Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(_isEditing ? 'Edit ${category.singular}' : 'New ${category.singular}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (_isSaving) const LinearProgressIndicator(),
              _ImagePickerCard(
                imagePath: _imagePath,
                placeholderIcon: category.icon,
                onPick: _pickImage,
                onRemove: () => setState(() => _imagePath = null),
              ),
              const SizedBox(height: 24),
              Text(
                'Details',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 12),
              for (final field in category.fields) ...[
                _buildField(field),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _isEditing ? 'Save changes' : 'Add ${category.singular}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(FieldSpec field) {
    final isMultiline = field.kind == FieldKind.multiline;
    final isTags = field.kind == FieldKind.tags;

    return TextFormField(
      controller: _controllers[field.key],
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        hintText: field.hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(field.icon),
        suffixText: field.kind == FieldKind.percent ? '%' : null,
        alignLabelWithHint: isMultiline,
      ),
      keyboardType: switch (field.kind) {
        FieldKind.integer || FieldKind.rarity => TextInputType.number,
        FieldKind.percent => const TextInputType.numberWithOptions(decimal: true),
        FieldKind.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      inputFormatters: switch (field.kind) {
        FieldKind.integer || FieldKind.rarity => [FilteringTextInputFormatter.digitsOnly],
        FieldKind.percent => [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        _ => null,
      },
      textCapitalization: isMultiline ? TextCapitalization.sentences : TextCapitalization.none,
      textInputAction: isMultiline ? TextInputAction.newline : TextInputAction.next,
      minLines: isMultiline ? 3 : 1,
      maxLines: isMultiline ? 6 : (isTags ? 3 : 1),
      validator: (value) => _validate(field, value),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  final String? imagePath;
  final IconData placeholderIcon;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerCard({
    required this.imagePath,
    required this.placeholderIcon,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imagePath != null;

    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPick,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              EntryImage(
                path: imagePath,
                placeholderIcon: Icons.add_a_photo_outlined,
                iconSize: 48,
              ),
              if (!hasImage)
                Align(
                  alignment: const Alignment(0, 0.55),
                  child: Text(
                    'Tap to add custom image',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              if (hasImage)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onPick,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Change'),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Remove image',
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
