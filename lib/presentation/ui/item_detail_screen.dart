import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/map_parsing.dart';
import '../../domain/entities/armor.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';
import '../../domain/entities/game_material.dart';
import '../../domain/entities/monster.dart';
import '../../domain/entities/weapon.dart';
import '../../domain/entities/charm.dart';
import '../../domain/entities/animal.dart';
import '../../domain/entities/game_map.dart';
import '../providers/game_providers.dart';
import 'category_ui.dart';
import 'entry_actions.dart';
import 'entry_widgets.dart';

/// Native Android encyclopedia page: image header, title block, a structured
/// stat table and cross references (Maps <-> Monsters/Animals <-> Materials).
class ItemDetailScreen extends ConsumerStatefulWidget {
  final EntryCategory category;
  final int entryId;

  const ItemDetailScreen({super.key, required this.category, required this.entryId});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  static const _expandedHeight = 300.0;
  final _scrollCtrl = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final collapsed = _scrollCtrl.hasClients &&
          _scrollCtrl.offset > _expandedHeight - kToolbarHeight - 48;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openFullScreenImage(BuildContext context, String imagePath, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            title: Text(title),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(entriesProvider(widget.category));
    final entry = entriesAsync.value?.where((e) => e.id == widget.entryId).firstOrNull;

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.category.singular)),
        body: Center(
          child: entriesAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('This entry no longer exists.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasImage = entry.imagePath != null && File(entry.imagePath!).existsSync();

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: _expandedHeight,
            leading: Center(
              child: _HeaderButton(
                floating: !_collapsed,
                tooltip: 'Back',
                icon: const BackButtonIcon(),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            title: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Text(displayName(entry.name)),
            ),
            actions: [
              if (hasImage) ...[
                _HeaderButton(
                  floating: !_collapsed,
                  tooltip: 'Zoom Image / Map Photo',
                  icon: const Icon(Icons.zoom_in_outlined),
                  onPressed: () => _openFullScreenImage(context, entry.imagePath!, entry.name),
                ),
                const SizedBox(width: 4),
              ],
              _HeaderButton(
                floating: !_collapsed,
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openEntryForm(context, entry.category, existing: entry),
              ),
              const SizedBox(width: 4),
              _HeaderButton(
                floating: !_collapsed,
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => confirmAndDeleteEntry(context, ref, entry, closeRoute: true),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: GestureDetector(
                onTap: hasImage
                    ? () => _openFullScreenImage(context, entry.imagePath!, entry.name)
                    : () => openEntryForm(context, entry.category, existing: entry),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'entry-image-${entry.category.name}-${entry.id}',
                      child: EntryImage(
                        path: entry.imagePath,
                        placeholderIcon: entry.category.icon,
                        width: double.infinity,
                        height: double.infinity,
                        iconSize: 96,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: hasImage
                            ? () => _openFullScreenImage(context, entry.imagePath!, entry.name)
                            : () => openEntryForm(context, entry.category, existing: entry),
                        icon: Icon(
                          hasImage ? Icons.fullscreen : Icons.add_a_photo_outlined,
                          size: 18,
                        ),
                        label: Text(
                          hasImage
                              ? (entry is GameMap ? 'Lihat Foto Map' : 'Zoom Foto')
                              : (entry is GameMap ? 'Tambah Foto Map' : 'Tambah Foto'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _TitleBlock(entry: entry)),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Information',
              icon: Icons.info_outline,
              children: [
                for (final field in entry.category.fields)
                  if (!entry.category.detailHiddenKeys.contains(field.key))
                    _StatRow(field: field, value: entry.toMap()[field.key]),
              ],
            ),
          ),
          if (entry is Monster) ...[
            SliverToBoxAdapter(child: _CreatureMapsSection(habitats: entry.habitatList)),
            SliverToBoxAdapter(child: _MonsterDropsSection(drops: entry.dropList)),
          ],
          if (entry is Animal) ...[
            SliverToBoxAdapter(child: _CreatureMapsSection(habitats: entry.habitatList)),
            SliverToBoxAdapter(child: _MonsterDropsSection(drops: entry.dropList)),
          ],
          if (entry is GameMaterial)
            SliverToBoxAdapter(child: _DroppedBySection(material: entry)),
          if (entry is GameMap)
            SliverToBoxAdapter(child: _MapEcosystemSection(gameMap: entry)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Text(
                'Database ID ${entry.id}${entryItemId(entry) != null ? ' · Item ID ${entryItemId(entry)}' : ' · Standalone'} · ${entry.category.singular}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// App bar icon button that gets a tonal "bubble" while floating over the
/// image so it stays legible on any picture.
class _HeaderButton extends StatelessWidget {
  final bool floating;
  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;

  const _HeaderButton({
    required this.floating,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return floating
        ? IconButton.filledTonal(tooltip: tooltip, icon: icon, onPressed: onPressed)
        : IconButton(tooltip: tooltip, icon: icon, onPressed: onPressed);
  }
}

class _TitleBlock extends StatelessWidget {
  final EncyclopediaEntry entry;

  const _TitleBlock({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rarity = entryRarity(entry);
    final itemId = entryItemId(entry);
    final e = entry;

    final String? tagline = switch (e) {
      Monster m => m.title,
      Armor a => a.stats,
      GameMaterial m => m.itemType,
      Weapon w => w.role,
      Charm c => c.stats,
      Animal an => an.habitat,
      GameMap gm => gm.deskripsi,
      _ => null,
    };

    final chips = <({IconData icon, String label})>[
      if (itemId != null) (icon: Icons.qr_code_2, label: 'Item ID #$itemId'),
      if (itemId == null) (icon: Icons.link_off_outlined, label: 'Standalone ID'),
      if (e is GameMaterial && e.itemDrop != null) (icon: Icons.place_outlined, label: e.itemDrop!),
      if (e is Armor && e.type != null) (icon: Icons.category_outlined, label: e.type!),
      if (e is Monster && e.classification != null)
        (icon: Icons.account_tree_outlined, label: e.classification!),
      if (e is Monster && e.habitat != null) (icon: Icons.terrain_outlined, label: e.habitat!),
      if (e is Monster && e.size != null) (icon: Icons.straighten, label: e.size!),
      if (e is Weapon && e.role != null) (icon: Icons.shield_outlined, label: e.role!),
      if (e is Animal && e.habitat != null) (icon: Icons.place_outlined, label: e.habitat!),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.category.singular.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, letterSpacing: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            displayName(entry.name),
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (tagline != null && tagline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(tagline, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          if (rarity != null || chips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (rarity != null) RarityBadge(rarity: rarity),
                for (final chip in chips)
                  Chip(
                    avatar: Icon(chip.icon, size: 18),
                    label: Text(chip.label),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Rounded M3 container with a small header, holding a list of rows.
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card.filled(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 52),
              children[i],
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// One "label : value" row in the Information table.
class _StatRow extends StatelessWidget {
  final FieldSpec field;
  final Object? value;

  const _StatRow({required this.field, required this.value});

  static String formatNumber(num value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final valueStyle = theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500);
    final raw = value;

    final Widget valueWidget;
    if (raw == null || (raw is String && raw.isEmpty)) {
      valueWidget = Text('-', style: valueStyle?.copyWith(color: scheme.outline));
    } else {
      valueWidget = switch (field.kind) {
        FieldKind.rarity => RarityBadge(rarity: MapParsing.asInt(raw) ?? 1, dense: true),
        FieldKind.percent => _PercentValue(fraction: MapParsing.asDouble(raw) ?? 0, style: valueStyle),
        FieldKind.tags => Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in MapParsing.splitTags('$raw'))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                ),
            ],
          ),
        _ => Text(
            raw is num ? formatNumber(raw) : '$raw',
            style: valueStyle,
            textAlign: field.kind == FieldKind.multiline ? TextAlign.start : TextAlign.end,
          ),
      };
    }

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(field.icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 16),
        Flexible(child: Text(field.label, style: labelStyle)),
      ],
    );

    if (field.kind == FieldKind.multiline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.only(left: 36), child: valueWidget),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: label),
          const SizedBox(width: 16),
          Expanded(child: Align(alignment: Alignment.centerRight, child: valueWidget)),
        ],
      ),
    );
  }
}

class _PercentValue extends StatelessWidget {
  final double fraction;
  final TextStyle? style;

  const _PercentValue({required this.fraction, required this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${_StatRow.formatNumber(fraction * 100)}%', style: style),
        const SizedBox(height: 6),
        SizedBox(
          width: 96,
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1).toDouble(),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

/// Links a Monster or Animal's habitat names directly to their GameMap entries.
class _CreatureMapsSection extends ConsumerWidget {
  final List<String> habitats;

  const _CreatureMapsSection({required this.habitats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (habitats.isEmpty) return const SizedBox.shrink();
    final maps = ref.watch(entriesProvider(EntryCategory.maps)).value ?? const [];
    final byName = {for (final m in maps) m.name.trim().toLowerCase(): m};

    return _Section(
      title: 'Habitat / Maps',
      icon: Icons.map_outlined,
      children: [
        for (final hab in habitats)
          _LinkedTile(
            name: hab,
            target: byName[hab.toLowerCase()],
            fallbackIcon: EntryCategory.maps.icon,
            missingText: 'Custom / Standalone Map (Tap Edit on Maps tab to add photo)',
          ),
      ],
    );
  }
}

/// "Drops" section on monster/animal pages, linking each drop to its Material entry.
class _MonsterDropsSection extends ConsumerWidget {
  final List<String> drops;

  const _MonsterDropsSection({required this.drops});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(entriesProvider(EntryCategory.materials)).value ?? const [];
    final byName = {for (final m in materials) m.name.trim().toLowerCase(): m};
    final scheme = Theme.of(context).colorScheme;

    return _Section(
      title: 'Item Drops',
      icon: Icons.inventory_2_outlined,
      children: drops.isEmpty
          ? [
              ListTile(
                title: Text('No drops recorded', style: TextStyle(color: scheme.outline)),
              ),
            ]
          : [
              for (final drop in drops)
                _LinkedTile(
                  name: drop,
                  target: byName[drop.toLowerCase()],
                  fallbackIcon: EntryCategory.materials.icon,
                  missingText: 'Custom / Standalone Drop (Not in Materials DB)',
                ),
            ],
    );
  }
}

/// "Dropped by / Source" section on material pages (reverse lookup of monster & animal drops + object_drop).
class _DroppedBySection extends ConsumerWidget {
  final GameMaterial material;

  const _DroppedBySection({required this.material});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monsters = ref.watch(entriesProvider(EntryCategory.monsters)).value ?? const [];
    final animals = ref.watch(entriesProvider(EntryCategory.animals)).value ?? const [];
    final maps = ref.watch(entriesProvider(EntryCategory.maps)).value ?? const [];

    final needle = (material.namaItem ?? material.name).trim().toLowerCase();
    final objectDropTags = MapParsing.splitTags(material.objectDrop);
    final objectDropLower = objectDropTags.map((e) => e.toLowerCase()).toSet();

    final linkedSources = <EncyclopediaEntry>[];
    final seenKeys = <String>{};

    void addIfNew(EncyclopediaEntry e) {
      final key = '${e.category.name}:${e.id ?? e.name.toLowerCase()}';
      if (seenKeys.add(key)) {
        linkedSources.add(e);
      }
    }

    for (final m in monsters.whereType<Monster>()) {
      if (m.dropList.any((d) => d.toLowerCase() == needle) ||
          objectDropLower.contains(m.name.trim().toLowerCase())) {
        addIfNew(m);
      }
    }
    for (final a in animals.whereType<Animal>()) {
      if (a.dropList.any((d) => d.toLowerCase() == needle) ||
          objectDropLower.contains(a.name.trim().toLowerCase())) {
        addIfNew(a);
      }
    }
    for (final gm in maps.whereType<GameMap>()) {
      if (objectDropLower.contains(gm.name.trim().toLowerCase())) {
        addIfNew(gm);
      }
    }

    final matchedNamesLower = linkedSources.map((e) => e.name.trim().toLowerCase()).toSet();
    final customSources = objectDropTags
        .where((tag) => !matchedNamesLower.contains(tag.toLowerCase()))
        .toList();

    if (linkedSources.isEmpty && customSources.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Section(
      title: 'Dropped By / Source',
      icon: Icons.pets_outlined,
      children: [
        for (final source in linkedSources)
          _LinkedTile(
            name: source.name,
            target: source,
            fallbackIcon: source.category.icon,
            missingText: '',
          ),
        for (final custom in customSources)
          _LinkedTile(
            name: custom,
            target: null,
            fallbackIcon: Icons.label_important_outline,
            missingText: 'Custom / Standalone Source',
          ),
      ],
    );
  }
}

/// Ecosystem overview on a Map detail page: Monsters, Animals, and Materials in this Map.
class _MapEcosystemSection extends ConsumerWidget {
  final GameMap gameMap;

  const _MapEcosystemSection({required this.gameMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapNameLower = gameMap.name.trim().toLowerCase();
    final monsters = ref.watch(entriesProvider(EntryCategory.monsters)).value ?? const [];
    final animals = ref.watch(entriesProvider(EntryCategory.animals)).value ?? const [];
    final materials = ref.watch(entriesProvider(EntryCategory.materials)).value ?? const [];

    bool matchesHabitat(List<String> habitatList, String? rawHabitat) {
      if (habitatList.any((h) => h.toLowerCase() == mapNameLower)) return true;
      if (rawHabitat != null && rawHabitat.toLowerCase().contains(mapNameLower)) return true;
      return false;
    }

    final mapMonsters = monsters
        .whereType<Monster>()
        .where((m) => matchesHabitat(m.habitatList, m.habitat))
        .toList();

    final mapAnimals = animals
        .whereType<Animal>()
        .where((a) => matchesHabitat(a.habitatList, a.habitat))
        .toList();

    // Collect drops from creatures in this map + materials directly linked to this map
    final creatureDropNames = <String>{
      for (final m in mapMonsters) ...m.dropList.map((d) => d.toLowerCase()),
      for (final a in mapAnimals) ...a.dropList.map((d) => d.toLowerCase()),
    };

    final mapMaterials = materials.whereType<GameMaterial>().where((mat) {
      final matName = mat.name.trim().toLowerCase();
      if (creatureDropNames.contains(matName)) return true;
      final objTags = MapParsing.splitTags(mat.objectDrop).map((t) => t.toLowerCase());
      return objTags.contains(mapNameLower);
    }).toList();

    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _Section(
          title: 'Monsters in ${gameMap.name} (${mapMonsters.length})',
          icon: EntryCategory.monsters.icon,
          children: mapMonsters.isEmpty
              ? [
                  ListTile(
                    title: Text('Belum ada Monster di map ini', style: TextStyle(color: scheme.outline)),
                  ),
                ]
              : [
                  for (final m in mapMonsters)
                    _LinkedTile(
                      name: m.name,
                      target: m,
                      fallbackIcon: EntryCategory.monsters.icon,
                      missingText: '',
                    ),
                ],
        ),
        _Section(
          title: 'Animals in ${gameMap.name} (${mapAnimals.length})',
          icon: EntryCategory.animals.icon,
          children: mapAnimals.isEmpty
              ? [
                  ListTile(
                    title: Text('Belum ada Animal di map ini', style: TextStyle(color: scheme.outline)),
                  ),
                ]
              : [
                  for (final a in mapAnimals)
                    _LinkedTile(
                      name: a.name,
                      target: a,
                      fallbackIcon: EntryCategory.animals.icon,
                      missingText: '',
                    ),
                ],
        ),
        _Section(
          title: 'Materials / Drops in ${gameMap.name} (${mapMaterials.length})',
          icon: EntryCategory.materials.icon,
          children: mapMaterials.isEmpty
              ? [
                  ListTile(
                    title: Text('Belum ada Material tercatat di map ini', style: TextStyle(color: scheme.outline)),
                  ),
                ]
              : [
                  for (final mat in mapMaterials)
                    _LinkedTile(
                      name: mat.name,
                      target: mat,
                      fallbackIcon: EntryCategory.materials.icon,
                      missingText: '',
                    ),
                ],
        ),
      ],
    );
  }
}

class _LinkedTile extends StatelessWidget {
  final String name;
  final EncyclopediaEntry? target;
  final IconData fallbackIcon;
  final String missingText;

  const _LinkedTile({
    required this.name,
    required this.target,
    required this.fallbackIcon,
    required this.missingText,
  });

  @override
  Widget build(BuildContext context) {
    final linked = target;
    final rarity = linked == null ? null : entryRarity(linked);
    final subtitle = linked == null ? missingText : entrySubtitle(linked);

    return ListTile(
      leading: EntryImage(
        path: linked?.imagePath,
        placeholderIcon: fallbackIcon,
        width: 40,
        height: 40,
        iconSize: 20,
        borderRadius: BorderRadius.circular(10),
      ),
      title: Text(displayName(name)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: linked == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rarity != null) RarityBadge(rarity: rarity, dense: true),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
      onTap: linked == null ? null : () => openEntryDetail(context, linked),
    );
  }
}
