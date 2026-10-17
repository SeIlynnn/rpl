import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/map_parsing.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/datasources/sqflite_data_source.dart';
import '../../domain/entities/animal.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';
import '../../domain/entities/game_map.dart';
import '../../domain/entities/game_material.dart';
import '../../domain/entities/monster.dart';
import '../providers/game_providers.dart';
import 'category_ui.dart';
import 'entry_widgets.dart';

enum ItemIdMode { globalAuto, custom, standalone }

/// Add / Edit form for any category with interactive relational pickers
/// (Maps, Monster/Animal Drops <-> Materials) and 3 Item ID modes
/// (Nyatu Global, Custom, Standalone).
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
  final TextEditingController _customDropInputCtrl = TextEditingController();
  final TextEditingController _customSourceInputCtrl = TextEditingController();
  final TextEditingController _customHabitatInputCtrl = TextEditingController();

  String? _imagePath;
  String? _originalImagePath;

  /// Images copied into app storage during this session (cleaned up if unused).
  final Set<String> _pickedImages = {};
  bool _isSaving = false;
  bool _saved = false;

  late ItemIdMode _itemIdMode;
  bool _syncDropsWithMaterials = true;
  bool _syncMaterialWithCreatures = true;
  bool _syncCustomMapToMapsTab = true;

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

    if (_isEditing) {
      final existingItemId = values['item_id'];
      _itemIdMode = existingItemId == null ? ItemIdMode.standalone : ItemIdMode.custom;
    } else {
      // Default to Global Auto for item categories, or Standalone for Maps/Monsters/Animals
      // (User can switch between all 3 modes anytime)
      final defaultGlobal = widget.category == EntryCategory.materials ||
          widget.category == EntryCategory.armors ||
          widget.category == EntryCategory.weapons ||
          widget.category == EntryCategory.charms;
      _itemIdMode = defaultGlobal ? ItemIdMode.globalAuto : ItemIdMode.standalone;
      if (_itemIdMode == ItemIdMode.standalone) {
        _controllers['item_id']?.text = '';
      }
    }

    _imagePath = existing?.imagePath;
    _originalImagePath = existing?.imagePath;
  }

  int _computeNextGlobalItemId() {
    var maxId = 0;
    for (final cat in EntryCategory.values) {
      final list = ref.read(entriesProvider(cat)).value ?? const [];
      for (final entry in list) {
        final v = entryItemId(entry) ?? MapParsing.asInt(entry.toMap()['item_id']) ?? 0;
        if (v > maxId) maxId = v;
      }
    }
    return maxId + 1;
  }

  int _computeNextCategoryNo(EntryCategory category) {
    final entries = ref.read(entriesProvider(category)).value ?? const [];
    var maxNo = 0;
    for (final entry in entries) {
      final v = MapParsing.asInt(entry.toMap()['no']) ?? 0;
      if (v > maxNo) maxNo = v;
    }
    return maxNo + 1;
  }

  /// Pre-fills `no` / `item_id` with the next free number for new records.
  Map<String, Object?> _defaultsForNewEntry() {
    final nextNo = _computeNextCategoryNo(widget.category);
    final nextGlobalId = _computeNextGlobalItemId();

    return {
      for (final field in widget.category.fields)
        if (field.key == 'no')
          'no': nextNo
        else if (field.key == 'item_id')
          'item_id': nextGlobalId,
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _customDropInputCtrl.dispose();
    _customSourceInputCtrl.dispose();
    _customHabitatInputCtrl.dispose();
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
    if (field.key == 'item_id') {
      if (_itemIdMode == ItemIdMode.standalone) return null;
      if (_itemIdMode == ItemIdMode.globalAuto && !_isEditing) {
        return int.tryParse(input.trim()) ?? _computeNextGlobalItemId();
      }
    }
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
    if (field.key == 'item_id' && _itemIdMode == ItemIdMode.standalone) {
      return null;
    }
    final text = input?.trim() ?? '';
    if (text.isEmpty) return field.required ? '${field.label} wajib diisi' : null;
    switch (field.kind) {
      case FieldKind.integer:
        if (int.tryParse(text) == null) return 'Masukkan angka bulat';
      case FieldKind.rarity:
        final rarity = int.tryParse(text);
        if (rarity == null || rarity < 1 || rarity > 10) return 'Rarity harus 1 – 10';
      case FieldKind.percent:
        final percent = double.tryParse(text.replaceAll(',', '.'));
        if (percent == null || percent < 0 || percent > 100) return 'Masukkan nilai 0 – 100';
      default:
        break;
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      final savedPath = await StorageUtils.persistImageLocally(xfile.path);
      if (savedPath == null || !mounted) return;
      setState(() {
        _pickedImages.add(savedPath);
        _imagePath = savedPath;
      });
    }
  }

  /// Synchronizes relationships after saving an entry:
  /// 1. Habitat -> Maps table (if `_syncCustomMapToMapsTab` is true)
  /// 2. Monster/Animal `item_drop` -> Materials table (if `_syncDropsWithMaterials` is true)
  /// 3. Material `object_drop` -> Monster/Animal `item_drop` (if `_syncMaterialWithCreatures` is true)
  Future<void> _performRelationalSync(EncyclopediaEntry savedEntry) async {
    // 1. Sync Habitat to Maps
    if (_syncCustomMapToMapsTab && (savedEntry is Monster || savedEntry is Animal)) {
      final rawHabitat = savedEntry is Monster
          ? savedEntry.habitat
          : (savedEntry as Animal).habitat;
      final habitats = MapParsing.splitHabitats(rawHabitat);
      if (habitats.isNotEmpty) {
        final existingMaps = ref.read(entriesProvider(EntryCategory.maps)).value ?? const [];
        final mapNamesLower = existingMaps.map((m) => m.name.trim().toLowerCase()).toSet();
        final mapNotifier = ref.read(entriesProvider(EntryCategory.maps).notifier);
        var nextMapNo = _computeNextCategoryNo(EntryCategory.maps);

        for (final hab in habitats) {
          if (!mapNamesLower.contains(hab.toLowerCase())) {
            final newMap = GameMap(
              no: nextMapNo++,
              name: hab,
              deskripsi: 'Area / Habitat untuk ${savedEntry.name}',
            );
            await mapNotifier.addEntry(newMap);
            mapNamesLower.add(hab.toLowerCase());
          }
        }
      }
    }

    // 2. Sync Monster / Animal drops -> Materials
    if (_syncDropsWithMaterials && (savedEntry is Monster || savedEntry is Animal)) {
      final drops = savedEntry is Monster
          ? savedEntry.dropList
          : (savedEntry as Animal).dropList;
      if (drops.isNotEmpty) {
        final existingMaterials =
            List<EncyclopediaEntry>.from(ref.read(entriesProvider(EntryCategory.materials)).value ?? const []);
        final matNotifier = ref.read(entriesProvider(EntryCategory.materials).notifier);
        var nextMatNo = _computeNextCategoryNo(EntryCategory.materials);
        var nextGlobalId = _computeNextGlobalItemId();

        final defaultDropCategory = savedEntry is Animal
            ? 'hewan'
            : ((savedEntry as Monster).classification?.toLowerCase().contains('small') ?? false)
                ? 'monster kecil'
                : 'Boss';

        for (final dropName in drops) {
          final existingMat = existingMaterials
              .whereType<GameMaterial>()
              .where((m) => m.name.trim().toLowerCase() == dropName.toLowerCase())
              .firstOrNull;

          if (existingMat == null) {
            final newMat = GameMaterial(
              no: nextMatNo++,
              itemId: nextGlobalId++,
              name: dropName,
              namaItem: dropName,
              rarity: 1,
              itemType: 'Material',
              itemDrop: defaultDropCategory,
              objectDrop: savedEntry.name,
              persentase: 1.0,
            );
            await matNotifier.addEntry(newMat);
            existingMaterials.add(newMat);
          } else {
            final currentObjects = MapParsing.splitTags(existingMat.objectDrop);
            final hasSource = currentObjects.any(
              (o) => o.toLowerCase() == savedEntry.name.trim().toLowerCase(),
            );
            if (!hasSource) {
              final updatedObjects = [...currentObjects, savedEntry.name].join(', ');
              final updatedMat = GameMaterial(
                id: existingMat.id,
                no: existingMat.no,
                itemId: existingMat.itemId,
                name: existingMat.name,
                namaItem: existingMat.namaItem,
                rarity: existingMat.rarity,
                itemType: existingMat.itemType ?? 'Material',
                itemDrop: existingMat.itemDrop ?? defaultDropCategory,
                objectDrop: updatedObjects,
                persentase: existingMat.persentase,
                imagePath: existingMat.imagePath,
              );
              await matNotifier.updateEntry(updatedMat);
            }
          }
        }
      }
    }

    // 3. Sync Material object_drop -> Monster / Animal item_drop
    if (_syncMaterialWithCreatures && savedEntry is GameMaterial) {
      final sourceNames = MapParsing.splitTags(savedEntry.objectDrop);
      if (sourceNames.isNotEmpty) {
        final monsters = ref.read(entriesProvider(EntryCategory.monsters)).value ?? const [];
        final animals = ref.read(entriesProvider(EntryCategory.animals)).value ?? const [];
        final monsterNotifier = ref.read(entriesProvider(EntryCategory.monsters).notifier);
        final animalNotifier = ref.read(entriesProvider(EntryCategory.animals).notifier);
        final matName = savedEntry.name.trim();

        for (final sourceName in sourceNames) {
          final lower = sourceName.toLowerCase();

          final matchedMonster = monsters
              .whereType<Monster>()
              .where((m) => m.name.trim().toLowerCase() == lower)
              .firstOrNull;
          if (matchedMonster != null) {
            final hasDrop = matchedMonster.dropList.any((d) => d.toLowerCase() == matName.toLowerCase());
            if (!hasDrop) {
              final newDrops = [...matchedMonster.dropList, matName].join(', ');
              final updatedMonster = Monster(
                id: matchedMonster.id,
                no: matchedMonster.no,
                itemId: matchedMonster.itemId,
                name: matchedMonster.name,
                title: matchedMonster.title,
                habitat: matchedMonster.habitat,
                classification: matchedMonster.classification,
                imunTo: matchedMonster.imunTo,
                itemDrop: newDrops,
                maxHealth: matchedMonster.maxHealth,
                def: matchedMonster.def,
                size: matchedMonster.size,
                imagePath: matchedMonster.imagePath,
              );
              await monsterNotifier.updateEntry(updatedMonster);
            }
          }

          final matchedAnimal = animals
              .whereType<Animal>()
              .where((a) => a.name.trim().toLowerCase() == lower)
              .firstOrNull;
          if (matchedAnimal != null) {
            final hasDrop = matchedAnimal.dropList.any((d) => d.toLowerCase() == matName.toLowerCase());
            if (!hasDrop) {
              final newDrops = [...matchedAnimal.dropList, matName].join(', ');
              final updatedAnimal = Animal(
                id: matchedAnimal.id,
                no: matchedAnimal.no,
                itemId: matchedAnimal.itemId,
                name: matchedAnimal.name,
                totalHp: matchedAnimal.totalHp,
                habitat: matchedAnimal.habitat,
                itemDrop: newDrops,
                imagePath: matchedAnimal.imagePath,
              );
              await animalNotifier.updateEntry(updatedAnimal);
            }
          }
        }
      }
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
      await _performRelationalSync(entry);
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
            ? '${widget.category.singular} berhasil diperbarui & disinkronkan'
            : '${widget.category.singular} berhasil ditambahkan & disinkronkan'),
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
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
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
                label: category == EntryCategory.maps
                    ? 'Tap untuk upload / ganti Foto Map'
                    : 'Tap untuk upload foto ${category.singular}',
                onPick: _pickImage,
                onRemove: () => setState(() => _imagePath = null),
              ),
              const SizedBox(height: 24),
              Text(
                'Detail & Relasi Data',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (final field in category.fields) ...[
                _buildFieldSection(field),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _isEditing ? 'Simpan Perubahan' : 'Tambah ${category.singular}',
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

  Widget _buildFieldSection(FieldSpec field) {
    if (field.key == 'item_id') {
      return _buildItemIdSelector(field);
    }
    if (field.key == 'rarity') {
      return _buildRaritySelector(field);
    }
    if (field.key == 'habitat') {
      return _buildHabitatMapPicker(field);
    }
    if (field.key == 'item_drop' &&
        (widget.category == EntryCategory.monsters || widget.category == EntryCategory.animals)) {
      return _buildCreatureDropsPicker(field);
    }
    if (field.key == 'item_drop' && widget.category == EntryCategory.materials) {
      return _buildMaterialDropCategoryPicker(field);
    }
    if (field.key == 'object_drop' && widget.category == EntryCategory.materials) {
      return _buildMaterialObjectDropPicker(field);
    }
    if (field.key == 'item_type' ||
        field.key == 'type' ||
        field.key == 'role' ||
        field.key == 'classification' ||
        field.key == 'size' ||
        field.key == 'imun_to') {
      return _buildQuickPresetField(field);
    }
    return _buildStandardTextField(field);
  }

  /// 1. 3-Mode Item ID Selector: Nyatu Global / Custom / Standalone
  Widget _buildItemIdSelector(FieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nextGlobal = _computeNextGlobalItemId();

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pengaturan Item ID',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<ItemIdMode>(
              segments: const [
                ButtonSegment(
                  value: ItemIdMode.globalAuto,
                  icon: Icon(Icons.auto_mode, size: 18),
                  label: Text('Nyatu (Auto)'),
                ),
                ButtonSegment(
                  value: ItemIdMode.custom,
                  icon: Icon(Icons.edit_note, size: 18),
                  label: Text('Custom ID'),
                ),
                ButtonSegment(
                  value: ItemIdMode.standalone,
                  icon: Icon(Icons.link_off, size: 18),
                  label: Text('Standalone'),
                ),
              ],
              selected: {_itemIdMode},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                setState(() {
                  _itemIdMode = mode;
                  if (mode == ItemIdMode.globalAuto) {
                    _controllers['item_id']?.text = '$nextGlobal';
                  } else if (mode == ItemIdMode.standalone) {
                    _controllers['item_id']?.text = '';
                  } else if (mode == ItemIdMode.custom && (_controllers['item_id']?.text.isEmpty ?? true)) {
                    _controllers['item_id']?.text = '$nextGlobal';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            if (_itemIdMode == ItemIdMode.standalone)
              Text(
                'Mode Standalone: Entitas ini berdiri sendiri tanpa Item ID global (hanya memakai ID tabel internal).',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _controllers[field.key],
                      readOnly: _itemIdMode == ItemIdMode.globalAuto,
                      decoration: InputDecoration(
                        labelText: _itemIdMode == ItemIdMode.globalAuto
                            ? 'Item ID Global Otomatis'
                            : 'Custom Item ID',
                        helperText: _itemIdMode == ItemIdMode.globalAuto
                            ? 'Otomatis melanjutkan urutan ID tertinggi di seluruh database'
                            : 'Ketik nomor ID sendiri atau samakan dengan ID yang sudah ada',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(field.icon),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => _validate(field, v),
                    ),
                  ),
                  if (_itemIdMode == ItemIdMode.custom) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Pilih dari ID yang sudah ada',
                      icon: const Icon(Icons.list_alt),
                      onPressed: _showExistingItemIdPicker,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showExistingItemIdPicker() async {
    final allEntries = ref.read(allEntriesProvider).value ?? const [];
    final withIds = allEntries.where((e) => entryItemId(e) != null).toList()
      ..sort((a, b) => (entryItemId(a) ?? 0).compareTo(entryItemId(b) ?? 0));

    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Pilih / Samakan dengan Item ID yang Ada',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: withIds.length,
                itemBuilder: (_, i) {
                  final e = withIds[i];
                  final idVal = entryItemId(e)!;
                  return ListTile(
                    leading: CircleAvatar(child: Text('$idVal', style: const TextStyle(fontSize: 12))),
                    title: Text(e.name),
                    subtitle: Text(e.category.singular),
                    onTap: () => Navigator.pop(ctx, idVal),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen != null && mounted) {
      setState(() {
        _controllers['item_id']?.text = '$chosen';
      });
    }
  }

  /// 2. Interactive Rarity Selector (1-6 + None/Standalone)
  Widget _buildRaritySelector(FieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentRarity = int.tryParse(_controllers[field.key]?.text.trim() ?? '');

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Rarity Tier',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (currentRarity != null) RarityBadge(rarity: currentRarity, dense: true),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tanpa Rarity'),
                  selected: currentRarity == null,
                  onSelected: (_) => setState(() => _controllers[field.key]?.text = ''),
                ),
                for (final r in [1, 2, 3, 4, 5, 6])
                  ChoiceChip(
                    label: Text('★ $r'),
                    selected: currentRarity == r,
                    onSelected: (_) => setState(() => _controllers[field.key]?.text = '$r'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Interactive Map / Habitat Selector (Pilih dari Maps yang ada / Buat Map Baru + Foto / Custom)
  Widget _buildHabitatMapPicker(FieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maps = ref.watch(entriesProvider(EntryCategory.maps)).value ?? const [];
    final monsters = ref.watch(entriesProvider(EntryCategory.monsters)).value ?? const [];
    final animals = ref.watch(entriesProvider(EntryCategory.animals)).value ?? const [];

    // Collect all known map names from Maps tab + existing Monster/Animal habitats
    final knownMaps = <String>{
      for (final m in maps) m.name.trim(),
      for (final m in monsters.whereType<Monster>()) ...m.habitatList,
      for (final a in animals.whereType<Animal>()) ...a.habitatList,
    }.where((s) => s.isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final selectedHabitats = MapParsing.splitHabitats(_controllers[field.key]?.text);
    final selectedLower = selectedHabitats.map((e) => e.toLowerCase()).toSet();

    void toggleHabitat(String mapName) {
      final list = List<String>.from(selectedHabitats);
      final idx = list.indexWhere((e) => e.toLowerCase() == mapName.toLowerCase());
      if (idx >= 0) {
        list.removeAt(idx);
      } else {
        list.add(mapName);
      }
      setState(() {
        _controllers[field.key]?.text = list.join(', ');
      });
    }

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Habitat / Map Lokasi',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showQuickCreateMapDialog,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('+ Buat Map & Foto'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih dari Map yang sudah ada (bisa lebih dari satu) atau ketik nama Map custom:',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            if (knownMaps.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mapName in knownMaps)
                    FilterChip(
                      avatar: const Icon(Icons.place_outlined, size: 16),
                      label: Text(mapName),
                      selected: selectedLower.contains(mapName.toLowerCase()),
                      onSelected: (_) => toggleHabitat(mapName),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _controllers[field.key],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nama Habitat / Map (Pisahkan dengan koma jika > 1)',
                hintText: 'Contoh: Lumera Lands, Luminer Cave',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(field.icon),
                suffixIcon: (_controllers[field.key]?.text.isNotEmpty ?? false)
                    ? IconButton(
                        tooltip: 'Kosongkan',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _controllers[field.key]?.text = ''),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Otomatis daftarkan Map custom baru ke Tab Maps'),
              subtitle: const Text('Jika dimatikan, nama map custom hanya tersimpan sebagai teks standalone'),
              value: _syncCustomMapToMapsTab,
              onChanged: (v) => setState(() => _syncCustomMapToMapsTab = v),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to quickly create a new Map with its own Map Photo directly from Monster/Animal form
  Future<void> _showQuickCreateMapDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? mapPhotoPath;

    final createdMap = await showDialog<GameMap>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Buat Map Baru + Foto Map'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final xfile = await picker.pickImage(source: ImageSource.gallery);
                    if (xfile != null) {
                      final saved = await StorageUtils.persistImageLocally(xfile.path);
                      if (saved != null) {
                        setDialogState(() => mapPhotoPath = saved);
                      }
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          EntryImage(
                            path: mapPhotoPath,
                            placeholderIcon: Icons.add_a_photo_outlined,
                            iconSize: 40,
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: FilledButton.tonalIcon(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final xfile = await picker.pickImage(source: ImageSource.gallery);
                                if (xfile != null) {
                                  final saved = await StorageUtils.persistImageLocally(xfile.path);
                                  if (saved != null) {
                                    setDialogState(() => mapPhotoPath = saved);
                                  }
                                }
                              },
                              icon: const Icon(Icons.photo_library_outlined, size: 16),
                              label: Text(mapPhotoPath == null ? 'Pilih Foto Map' : 'Ganti Foto'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Map *',
                    hintText: 'Misal: Crystal Cavern',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Map (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  ctx,
                  GameMap(
                    no: _computeNextCategoryNo(EntryCategory.maps),
                    name: name,
                    deskripsi: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    imagePath: mapPhotoPath,
                  ),
                );
              },
              child: const Text('Simpan & Pilih Map'),
            ),
          ],
        ),
      ),
    );

    if (createdMap != null && mounted) {
      await ref.read(entriesProvider(EntryCategory.maps).notifier).addEntry(createdMap);
      final current = MapParsing.splitHabitats(_controllers['habitat']?.text);
      if (!current.any((h) => h.toLowerCase() == createdMap.name.toLowerCase())) {
        current.add(createdMap.name);
      }
      setState(() {
        _controllers['habitat']?.text = current.join(', ');
      });
    }
  }

  /// 4. Interactive Creature Drops Picker (Monster & Animal -> Materials)
  Widget _buildCreatureDropsPicker(FieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final materials = ref.watch(entriesProvider(EntryCategory.materials)).value ?? const [];
    final materialByName = {
      for (final m in materials.whereType<GameMaterial>()) m.name.trim().toLowerCase(): m,
    };

    final currentDrops = MapParsing.splitTags(_controllers[field.key]?.text);

    void updateDrops(List<String> newDrops) {
      setState(() {
        _controllers[field.key]?.text = newDrops.join(', ');
      });
    }

    void addCustomDrop() {
      final text = _customDropInputCtrl.text.trim();
      if (text.isEmpty) return;
      final newItems = MapParsing.splitTags(text);
      final updated = List<String>.from(currentDrops);
      for (final item in newItems) {
        if (!updated.any((e) => e.toLowerCase() == item.toLowerCase())) {
          updated.add(item);
        }
      }
      _customDropInputCtrl.clear();
      updateDrops(updated);
    }

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Item Drops (Pilih Material atau Buat Baru)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showMultiSelectMaterialsSheet(currentDrops, updateDrops),
                  icon: const Icon(Icons.checklist, size: 18),
                  label: const Text('Pilih Material'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (currentDrops.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Belum ada item drop dipilih.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final drop in currentDrops)
                    InputChip(
                      avatar: Icon(
                        materialByName.containsKey(drop.toLowerCase())
                            ? Icons.link
                            : Icons.fiber_new_outlined,
                        size: 16,
                      ),
                      label: Text(drop),
                      tooltip: materialByName.containsKey(drop.toLowerCase())
                          ? 'Tersambung dengan Material di DB'
                          : (_syncDropsWithMaterials
                              ? 'Akan otomatis dibuatkan di kategori Materials saat disimpan'
                              : 'Standalone Drop'),
                      onDeleted: () {
                        final next = List<String>.from(currentDrops)
                          ..removeWhere((e) => e.toLowerCase() == drop.toLowerCase());
                        updateDrops(next);
                      },
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customDropInputCtrl,
                    onSubmitted: (_) => addCustomDrop(),
                    decoration: const InputDecoration(
                      labelText: 'Ketik Item Drop Baru / Custom (misal: Batu)',
                      hintText: 'Ketik nama item lalu tekan +',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Tambahkan ke daftar drop',
                  onPressed: addCustomDrop,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Otomatis sambungkan / buat di Kategori Materials'),
              subtitle: const Text(
                'Jika aktif, item drop baru (misal "Batu") otomatis masuk ke daftar Material & tersambung',
              ),
              value: _syncDropsWithMaterials,
              onChanged: (v) => setState(() => _syncDropsWithMaterials = v),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMultiSelectMaterialsSheet(
    List<String> currentDrops,
    ValueChanged<List<String>> onChanged,
  ) async {
    final materials = ref.read(entriesProvider(EntryCategory.materials)).value ?? const [];
    final selected = List<String>.from(currentDrops);
    String search = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = materials.where((m) {
            if (search.isEmpty) return true;
            return m.name.toLowerCase().contains(search.toLowerCase());
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.92,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pilih Item Drop dari Materials (${selected.length} dipilih)',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Selesai'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    onChanged: (v) => setSheetState(() => search = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama material...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const Divider(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final mat = filtered[i];
                      final isChecked = selected.any((s) => s.toLowerCase() == mat.name.toLowerCase());
                      final rarity = entryRarity(mat);
                      return CheckboxListTile(
                        value: isChecked,
                        title: Text(mat.name),
                        subtitle: Text(entrySubtitle(mat)),
                        secondary: rarity != null ? RarityBadge(rarity: rarity, dense: true) : null,
                        onChanged: (checked) {
                          setSheetState(() {
                            if (checked == true) {
                              if (!isChecked) selected.add(mat.name);
                            } else {
                              selected.removeWhere((s) => s.toLowerCase() == mat.name.toLowerCase());
                            }
                          });
                          onChanged(List<String>.from(selected));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 5. Material Drop Category Picker (`item_drop` on GameMaterial: Boss, monster kecil, hewan, Tumbuhan, Pohon, Rock, Custom)
  Widget _buildMaterialDropCategoryPicker(FieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final presetKey = '${widget.category.tableName}.${field.key}';
    final presetsAsync = ref.watch(fieldPresetsProvider(presetKey));
    final presets = presetsAsync.value ??
        SqfliteDataSource.defaultFieldPresets[presetKey] ??
        const <String>[];
    final currentText = _controllers[field.key]?.text.trim() ?? '';
    final isCustomTyped = currentText.isNotEmpty &&
        !presets.any((p) => p.toLowerCase() == currentText.toLowerCase());

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(field.icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kategori Sumber Drop (Item Drop)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddPresetDialog(
                    presetKey,
                    'Kategori Drop',
                    onAdded: (val) => setState(() => _controllers[field.key]?.text = val),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('+ Saran'),
                ),
              ],
            ),
            Text(
              'Ketuk saran untuk memilih, atau tekan (×) pada chip untuk menghapus saran yang tidak relevan:',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Standalone (Kosong)'),
                  selected: currentText.isEmpty,
                  onSelected: (_) => setState(() => _controllers[field.key]?.text = ''),
                ),
                for (final preset in presets)
                  InputChip(
                    label: Text(preset),
                    selected: currentText.toLowerCase() == preset.toLowerCase(),
                    onSelected: (_) => setState(() => _controllers[field.key]?.text = preset),
                    deleteButtonTooltipMessage: 'Hapus saran "$preset"',
                    onDeleted: () => _handleDeletePreset(presetKey, preset),
                  ),
                if (isCustomTyped)
                  ActionChip(
                    avatar: const Icon(Icons.bookmark_add_outlined, size: 16),
                    label: Text('Simpan "$currentText" ke Saran'),
                    onPressed: () =>
                        ref.read(fieldPresetsProvider(presetKey).notifier).addPreset(currentText),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _controllers[field.key],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Kategori Drop (Pilih di atas atau ketik custom)',
                hintText: field.hint,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(field.icon),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 6. Material Specific Drop Source Picker (`object_drop` on GameMaterial: Monster / Animal / Map / Custom)
  Widget _buildMaterialObjectDropPicker(FieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final monsters = ref.watch(entriesProvider(EntryCategory.monsters)).value ?? const [];
    final animals = ref.watch(entriesProvider(EntryCategory.animals)).value ?? const [];
    final maps = ref.watch(entriesProvider(EntryCategory.maps)).value ?? const [];

    // Also find monsters/animals that already list this material in their `item_drop`
    final currentMatName = (_controllers['nama_item']?.text ?? '').trim().toLowerCase();
    final reverseMatchedCreatures = <String>[
      if (currentMatName.isNotEmpty) ...[
        for (final m in monsters.whereType<Monster>())
          if (m.dropList.any((d) => d.toLowerCase() == currentMatName)) m.name,
        for (final a in animals.whereType<Animal>())
          if (a.dropList.any((d) => d.toLowerCase() == currentMatName)) a.name,
      ],
    ];

    final currentSources = MapParsing.splitTags(_controllers[field.key]?.text);

    void updateSources(List<String> next) {
      setState(() {
        _controllers[field.key]?.text = next.join(', ');
      });
    }

    void addCustomSource() {
      final text = _customSourceInputCtrl.text.trim();
      if (text.isEmpty) return;
      final tags = MapParsing.splitTags(text);
      final next = List<String>.from(currentSources);
      for (final t in tags) {
        if (!next.any((e) => e.toLowerCase() == t.toLowerCase())) {
          next.add(t);
        }
      }
      _customSourceInputCtrl.clear();
      updateSources(next);
    }

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Drop Dari Mana? (Monster / Animal / Map / Custom)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showEntitySourcePicker(
                    title: 'Pilih Monster Penghasil Drop',
                    entries: monsters,
                    currentSources: currentSources,
                    onSelected: (next) {
                      updateSources(next);
                      if ((_controllers['item_drop']?.text.trim().isEmpty ?? true) && next.isNotEmpty) {
                        _controllers['item_drop']?.text = 'Boss';
                      }
                    },
                  ),
                  icon: Icon(EntryCategory.monsters.icon, size: 18),
                  label: const Text('+ Monster'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showEntitySourcePicker(
                    title: 'Pilih Animal Penghasil Drop',
                    entries: animals,
                    currentSources: currentSources,
                    onSelected: (next) {
                      updateSources(next);
                      if ((_controllers['item_drop']?.text.trim().isEmpty ?? true) && next.isNotEmpty) {
                        _controllers['item_drop']?.text = 'hewan';
                      }
                    },
                  ),
                  icon: Icon(EntryCategory.animals.icon, size: 18),
                  label: const Text('+ Animal'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showEntitySourcePicker(
                    title: 'Pilih Map Lokasi Drop',
                    entries: maps,
                    currentSources: currentSources,
                    onSelected: updateSources,
                  ),
                  icon: Icon(EntryCategory.maps.icon, size: 18),
                  label: const Text('+ Map'),
                ),
              ],
            ),
            if (reverseMatchedCreatures.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Sudah tercatat di drop milik: ${reverseMatchedCreatures.join(", ")}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
              ),
            ],
            const SizedBox(height: 10),
            if (currentSources.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final src in currentSources)
                    InputChip(
                      label: Text(src),
                      onDeleted: () {
                        final next = List<String>.from(currentSources)
                          ..removeWhere((e) => e.toLowerCase() == src.toLowerCase());
                        updateSources(next);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customSourceInputCtrl,
                    onSubmitted: (_) => addCustomSource(),
                    decoration: const InputDecoration(
                      labelText: 'Atau ketik sumber Custom / Standalone',
                      hintText: 'Misal: Batu Kristal, Pohon Tua...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Tambah sumber custom',
                  onPressed: addCustomSource,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Otomatis masukkan item ini ke daftar Drop Monster/Animal yang dipilih'),
              subtitle: const Text(
                'Jika pilih Animal/Monster yang ada (misal Albus), item ini otomatis masuk ke drop Albus',
              ),
              value: _syncMaterialWithCreatures,
              onChanged: (v) => setState(() => _syncMaterialWithCreatures = v),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEntitySourcePicker({
    required String title,
    required List<EncyclopediaEntry> entries,
    required List<String> currentSources,
    required ValueChanged<List<String>> onSelected,
  }) async {
    final selected = List<String>.from(currentSources);
    String search = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = entries.where((e) {
            if (search.isEmpty) return true;
            return e.name.toLowerCase().contains(search.toLowerCase());
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Selesai'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    onChanged: (v) => setSheetState(() => search = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const Divider(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final isChecked = selected.any((s) => s.toLowerCase() == e.name.toLowerCase());
                      return CheckboxListTile(
                        value: isChecked,
                        title: Text(e.name),
                        subtitle: Text(entrySubtitle(e)),
                        onChanged: (checked) {
                          setSheetState(() {
                            if (checked == true) {
                              if (!isChecked) selected.add(e.name);
                            } else {
                              selected.removeWhere((s) => s.toLowerCase() == e.name.toLowerCase());
                            }
                          });
                          onSelected(List<String>.from(selected));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 7. Customizable Quick-Preset Chips (Tambah / Hapus Saran) + Custom Input
  /// for `item_type`, `type`, `role`, `classification`, `size`, and `imun_to`.
  Widget _buildQuickPresetField(FieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final presetKey = '${widget.category.tableName}.${field.key}';
    final presetsAsync = ref.watch(fieldPresetsProvider(presetKey));
    final presets = presetsAsync.value ??
        SqfliteDataSource.defaultFieldPresets[presetKey] ??
        const <String>[];

    final isMultiTag = field.kind == FieldKind.tags;
    final currentText = _controllers[field.key]?.text.trim() ?? '';
    final currentTags = isMultiTag ? MapParsing.splitTags(currentText) : const <String>[];
    final currentTagsLower = currentTags.map((e) => e.toLowerCase()).toSet();

    void onTapPreset(String preset) {
      if (isMultiTag) {
        final next = List<String>.from(currentTags);
        final idx = next.indexWhere((e) => e.toLowerCase() == preset.toLowerCase());
        if (idx >= 0) {
          next.removeAt(idx);
        } else {
          next.add(preset);
        }
        setState(() {
          _controllers[field.key]?.text = next.join(', ');
        });
      } else {
        setState(() {
          if (currentText.toLowerCase() == preset.toLowerCase()) {
            _controllers[field.key]?.text = '';
          } else {
            _controllers[field.key]?.text = preset;
          }
        });
      }
    }

    final isCustomTyped = !isMultiTag &&
        currentText.isNotEmpty &&
        !presets.any((p) => p.toLowerCase() == currentText.toLowerCase());

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(field.icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saran ${field.label}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _showAddPresetDialog(
                    presetKey,
                    field.label,
                    onAdded: (val) => onTapPreset(val),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('+ Tambah Saran'),
                ),
              ],
            ),
            Text(
              'Ketuk untuk memilih, atau tekan (×) untuk menghapus saran yang tidak relevan:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final p in presets)
                  InputChip(
                    label: Text(p),
                    visualDensity: VisualDensity.compact,
                    selected: isMultiTag
                        ? currentTagsLower.contains(p.toLowerCase())
                        : currentText.toLowerCase() == p.toLowerCase(),
                    onSelected: (_) => onTapPreset(p),
                    deleteButtonTooltipMessage: 'Hapus saran "$p"',
                    onDeleted: () => _handleDeletePreset(presetKey, p),
                  ),
                if (isCustomTyped)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.bookmark_add_outlined, size: 16),
                    label: Text('Simpan "$currentText" ke Saran'),
                    onPressed: () =>
                        ref.read(fieldPresetsProvider(presetKey).notifier).addPreset(currentText),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildStandardTextField(field),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeletePreset(String presetKey, String presetValue) async {
    await ref.read(fieldPresetsProvider(presetKey).notifier).removePreset(presetValue);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Saran "$presetValue" dihapus.'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () {
              ref.read(fieldPresetsProvider(presetKey).notifier).addPreset(presetValue);
            },
          ),
        ),
      );
  }

  Future<void> _showAddPresetDialog(
    String presetKey,
    String fieldLabel, {
    ValueChanged<String>? onAdded,
  }) async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Saran $fieldLabel'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
          decoration: InputDecoration(
            labelText: 'Nama Saran / Kategori Baru',
            hintText: 'Ketik saran untuk $fieldLabel...',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            icon: const Icon(Icons.add),
            label: const Text('Simpan Saran'),
          ),
        ],
      ),
    );

    if (added != null && added.isNotEmpty && mounted) {
      await ref.read(fieldPresetsProvider(presetKey).notifier).addPreset(added);
      onAdded?.call(added);
    }
  }

  Widget _buildStandardTextField(FieldSpec field) {
    final isMultiline = field.kind == FieldKind.multiline;
    final isTags = field.kind == FieldKind.tags;

    return TextFormField(
      controller: _controllers[field.key],
      onChanged: (_) => setState(() {}),
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
  final String label;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerCard({
    required this.imagePath,
    required this.placeholderIcon,
    required this.label,
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
                    label,
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
                        label: const Text('Ganti Foto'),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Hapus foto',
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
