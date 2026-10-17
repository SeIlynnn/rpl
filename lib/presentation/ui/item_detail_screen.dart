import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/map_parsing.dart';
import '../../domain/entities/armor.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/entry_category.dart';
import '../../domain/entities/game_material.dart';
import '../../domain/entities/monster.dart';
import '../providers/game_providers.dart';
import 'category_ui.dart';
import 'entry_actions.dart';
import 'entry_widgets.dart';

/// Native Android encyclopedia page: image header, title block, a structured
/// stat table and cross references (Monster drops <-> Materials).
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
              background: Hero(
                tag: 'entry-image-${entry.category.name}-${entry.id}',
                child: EntryImage(
                  path: entry.imagePath,
                  placeholderIcon: entry.category.icon,
                  width: double.infinity,
                  height: double.infinity,
                  iconSize: 96,
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
          if (entry is Monster) SliverToBoxAdapter(child: _MonsterDropsSection(monster: entry)),
          if (entry is GameMaterial) SliverToBoxAdapter(child: _DroppedBySection(material: entry)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Text(
                'Database ID ${entry.id} · ${entry.category.singular}',
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
    final e = entry;

    final String? tagline = switch (e) {
      Monster m => m.title,
      Armor a => a.stats,
      GameMaterial m => m.itemType,
      _ => null,
    };

    final chips = <({IconData icon, String label})>[
      if (e is GameMaterial && e.itemDrop != null) (icon: Icons.place_outlined, label: e.itemDrop!),
      if (e is Armor && e.type != null) (icon: Icons.category_outlined, label: e.type!),
      if (e is Monster && e.classification != null)
        (icon: Icons.account_tree_outlined, label: e.classification!),
      if (e is Monster && e.habitat != null) (icon: Icons.terrain_outlined, label: e.habitat!),
      if (e is Monster && e.size != null) (icon: Icons.straighten, label: e.size!),
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
          if (tagline != null) ...[
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
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
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
      valueWidget = Text('—', style: valueStyle?.copyWith(color: scheme.outline));
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
        Text(field.label, style: labelStyle),
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
          label,
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

/// "Drops" section on monster pages, linking each drop to its Material entry.
class _MonsterDropsSection extends ConsumerWidget {
  final Monster monster;

  const _MonsterDropsSection({required this.monster});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drops = monster.dropList;
    final materials = ref.watch(entriesProvider(EntryCategory.materials)).value ?? const [];
    final byName = {for (final m in materials) m.name.trim().toLowerCase(): m};
    final scheme = Theme.of(context).colorScheme;

    return _Section(
      title: 'Drops',
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
                  missingText: 'Not in the Materials database',
                ),
            ],
    );
  }
}

/// "Dropped by" section on material pages (reverse lookup of monster drops).
class _DroppedBySection extends ConsumerWidget {
  final GameMaterial material;

  const _DroppedBySection({required this.material});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monsters = ref.watch(entriesProvider(EntryCategory.monsters)).value ?? const [];
    final needle = (material.namaItem ?? material.name).trim().toLowerCase();
    final sources = monsters
        .whereType<Monster>()
        .where((m) => m.dropList.any((d) => d.toLowerCase() == needle))
        .toList(growable: false);
    if (sources.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Dropped by',
      icon: Icons.pets_outlined,
      children: [
        for (final monster in sources)
          _LinkedTile(
            name: monster.name,
            target: monster,
            fallbackIcon: EntryCategory.monsters.icon,
            missingText: '',
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
