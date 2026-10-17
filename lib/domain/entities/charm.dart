import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Charm extends EncyclopediaEntry {
  final int? rarity;
  final String? stats;

  Charm({
    super.id,
    required super.name,
    super.imagePath,
    this.rarity,
    this.stats,
  });

  @override
  EntryCategory get category => EntryCategory.charms;

  @override
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nama_item': name,
      'image_path': imagePath,
      'rarity': rarity,
      'stats': stats,
    };
  }

  factory Charm.fromMap(Map<String, Object?> map) {
    return Charm(
      id: map['id'] as int?,
      name: map['nama_item'] as String? ?? '',
      imagePath: map['image_path'] as String?,
      stats: map['stats'] as String?,
      rarity: map['rarity'] as int?,
    );
  }
}