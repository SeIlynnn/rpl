import '../../core/utils/map_parsing.dart';
import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Weapon extends EncyclopediaEntry {
  final int? no;
  final int? itemId;
  final int? rarity;
  final String? role;
  final String? normalStats;
  final String? negativeStats;
  final String? skillAktif;

  Weapon({
    super.id,
    required super.name,
    super.imagePath,
    this.no,
    this.itemId,
    this.rarity,
    this.role,
    this.normalStats,
    this.negativeStats,
    this.skillAktif,
  });

  @override
  EntryCategory get category => EntryCategory.weapons;

  @override
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'no': no,
      'item_id': itemId,
      'nama_item': name,
      'rarity': rarity,
      'role': role,
      'normal_stats': normalStats,
      'negative_stats': negativeStats,
      'skill_aktif': skillAktif,
      'image_path': imagePath,
    };
  }

  factory Weapon.fromMap(Map<String, Object?> map) {
    return Weapon(
      id: MapParsing.asInt(map['id']),
      no: MapParsing.asInt(map['no']),
      itemId: MapParsing.asInt(map['item_id']),
      name: MapParsing.asString(map['nama_item']) ?? '',
      rarity: MapParsing.asInt(map['rarity']),
      role: MapParsing.asString(map['role']),
      normalStats: MapParsing.asString(map['normal_stats']),
      negativeStats: MapParsing.asString(map['negative_stats']),
      skillAktif: MapParsing.asString(map['skill_aktif']),
      imagePath: MapParsing.asString(map['image_path']),
    );
  }
}