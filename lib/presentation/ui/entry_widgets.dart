import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/monster.dart';
import '../../domain/entities/game_material.dart';
import '../../domain/entities/armor.dart';
import '../../domain/entities/weapon.dart';
import '../../domain/entities/charm.dart';
import '../../domain/entities/animal.dart';
import '../../domain/entities/game_map.dart';

class EntryImage extends StatelessWidget {
  final String? path;
  final IconData placeholderIcon;
  final double? width;
  final double? height;
  final double iconSize;
  final BorderRadius? borderRadius;

  const EntryImage({
    super.key,
    this.path,
    required this.placeholderIcon,
    this.width,
    this.height,
    this.iconSize = 24,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget imageWidget;

    if (path != null && File(path!).existsSync()) {
      imageWidget = Image.file(File(path!), fit: BoxFit.cover, width: width, height: height);
    } else {
      imageWidget = Container(
        width: width,
        height: height,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(placeholderIcon, size: iconSize, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }
    return imageWidget;
  }
}

class RarityBadge extends StatelessWidget {
  final int rarity;
  final bool dense;

  const RarityBadge({super.key, required this.rarity, this.dense = false});

  @override
  Widget build(BuildContext context) {
    // Game tier color palette: Grey (1), Green (2), Blue (3), Purple (4), Gold (5), Red (6+)
    final colors = [
      const Color(0xFF9E9E9E), // R1 - Common
      const Color(0xFF4CAF50), // R2 - Uncommon
      const Color(0xFF2196F3), // R3 - Rare
      const Color(0xFF9C27B0), // R4 - Epic
      const Color(0xFFFFB300), // R5 - Legendary
      const Color(0xFFF44336), // R6 - Mythic
    ];
    final color = (rarity >= 1 && rarity <= colors.length)
        ? colors[rarity - 1]
        : const Color(0xFF9E9E9E);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(dense ? 6 : 8),
        border: Border.all(
          color: color.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.star_rounded,
            size: dense ? 13 : 16,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '$rarity',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: dense ? 11 : 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

String displayName(String name) => name;

int? entryRarity(EncyclopediaEntry entry) {
  if (entry is GameMaterial) return entry.rarity;
  if (entry is Armor) return entry.rarity;
  if (entry is Weapon) return entry.rarity;
  if (entry is Charm) return entry.rarity;
  return null;
}

int? entryItemId(EncyclopediaEntry entry) {
  if (entry is GameMaterial) return entry.itemId;
  if (entry is Armor) return entry.itemId;
  if (entry is Monster) return entry.itemId;
  if (entry is Weapon) return entry.itemId;
  if (entry is Charm) return entry.itemId;
  if (entry is Animal) return entry.itemId;
  if (entry is GameMap) return entry.itemId;
  return null;
}

String entrySubtitle(EncyclopediaEntry entry) {
  if (entry is Monster) {
    final parts = [
      if (entry.classification != null && entry.classification!.isNotEmpty) entry.classification!,
      if (entry.habitat != null && entry.habitat!.isNotEmpty) entry.habitat!,
    ];
    return parts.isEmpty ? (entry.title ?? '') : parts.join(' • ');
  }
  if (entry is Animal) {
    return '${entry.habitat ?? ''}${entry.totalHp != null ? ' • HP: ${entry.totalHp}' : ''}';
  }
  if (entry is Armor) {
    return '${entry.type ?? ''}${entry.stats != null && entry.stats!.isNotEmpty ? ' • ${entry.stats}' : ''}';
  }
  if (entry is GameMaterial) {
    final parts = [
      if (entry.itemType != null && entry.itemType!.isNotEmpty) entry.itemType!,
      if (entry.itemDrop != null && entry.itemDrop!.isNotEmpty) entry.itemDrop!,
      if (entry.objectDrop != null && entry.objectDrop!.isNotEmpty) entry.objectDrop!,
    ];
    return parts.join(' • ');
  }
  if (entry is Weapon) {
    return '${entry.role ?? ''}${entry.normalStats != null && entry.normalStats!.isNotEmpty ? ' • ${entry.normalStats}' : ''}';
  }
  if (entry is Charm) return entry.stats ?? '';
  if (entry is GameMap) return entry.deskripsi ?? 'Habitat / Map Area';
  return '';
}