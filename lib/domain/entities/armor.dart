import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Armor extends EncyclopediaEntry {
  final String? type;
  final String? stats;
  final int? rarity;

  Armor({
    super.id,
    required super.name,
    super.imagePath,
    this.rarity,
    this.type,
    this.stats,
  });

  @override
  EntryCategory get category => EntryCategory.armors;

  @override
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nama_item': name, // <--- Sesuaikan dengan DB (nama_item)
      'image_path': imagePath,
      'rarity': rarity,
      'type': type,
      'stats': stats,
    };
  }

  factory Armor.fromMap(Map<String, Object?> map) {
    return Armor(
      id: map['id'] as int?,
      name: map['nama_item'] as String? ?? '', // <--- Ambil dari DB (nama_item)
      imagePath: map['image_path'] as String?,
      rarity: map['rarity'] as int?,
      type: map['type'] as String?,
      stats: map['stats'] as String?,
    );
  }
}