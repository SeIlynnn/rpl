import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/encyclopedia_entry.dart';
import '../../domain/entities/monster.dart';
import '../../domain/entities/game_material.dart';
import '../../domain/entities/armor.dart';
import '../../domain/entities/animal.dart';

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
    final colors = [Colors.grey, Colors.green, Colors.blue, Colors.purple, Colors.orange, Colors.red];
    final color = rarity > 0 && rarity <= colors.length ? colors[rarity - 1] : Colors.grey;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Text('R$rarity', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: dense ? 10 : 12)),
    );
  }
}

String displayName(String name) => name;

int? entryRarity(EncyclopediaEntry entry) => null;

String entrySubtitle(EncyclopediaEntry entry) {
  if (entry is Monster) return entry.classification ?? '';
  if (entry is Animal) return '${entry.habitat ?? ''} · HP: ${entry.totalHp ?? '-'}'; // Tambahkan ini
  if (entry is Armor) return entry.type ?? '';
  if (entry is GameMaterial) return entry.itemType ?? '';
  return '';
}