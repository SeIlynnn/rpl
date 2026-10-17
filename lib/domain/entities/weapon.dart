import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Weapon extends EncyclopediaEntry {
  final String? role;
  final String? skillAktif;
  final int? rarity;
  final String? normalStats;   // Ganti element
  final String? negativeStats; // Tambahan baru

  Weapon({
    super.id,
    required super.name,
    super.imagePath,
    this.rarity,
    this.skillAktif,
    this.role,
    this.normalStats,
    this.negativeStats,
  });

  @override
  EntryCategory get category => EntryCategory.weapons;

  @override
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nama_item': name,
      'image_path': imagePath,
      'role': role,
      'rarity': rarity,
      'skill_aktif': skillAktif,
      'normal_stats': normalStats,
      'negative_stats': negativeStats,
    };
  }

  factory Weapon.fromMap(Map<String, Object?> map) {
    return Weapon(
      id: map['id'] as int?,
      name: map['nama_item'] as String? ?? '',
      imagePath: map['image_path'] as String?,
      role: map['role'] as String?,
      rarity: map['rarity'] as int?,
      skillAktif: map['skill_aktif'] as String?,
      normalStats: map['normal_stats'] as String?,
      negativeStats: map['negative_stats'] as String?,
    );
  }
}