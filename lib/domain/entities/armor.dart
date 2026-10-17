import '../../core/utils/map_parsing.dart';
import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Armor extends EncyclopediaEntry {
  final int? no;
  final int? itemId;
  final int? rarity;
  final String? type;
  final String? stats;
  final String? skill;

  Armor({
    super.id,
    required super.name,
    super.imagePath,
    this.no,
    this.itemId,
    this.rarity,
    this.type,
    this.stats,
    this.skill,
  });

  @override
  EntryCategory get category => EntryCategory.armors;

  @override
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'no': no,
      'item_id': itemId,
      'nama_item': name,
      'rarity': rarity,
      'type': type,
      'stats': stats,
      'skill': skill,
      'image_path': imagePath,
    };
  }

  factory Armor.fromMap(Map<String, Object?> map) {
    return Armor(
      id: MapParsing.asInt(map['id']),
      no: MapParsing.asInt(map['no']),
      itemId: MapParsing.asInt(map['item_id']),
      name: MapParsing.asString(map['nama_item']) ?? '',
      rarity: MapParsing.asInt(map['rarity']),
      type: MapParsing.asString(map['type']),
      stats: MapParsing.asString(map['stats']),
      skill: MapParsing.asString(map['skill']),
      imagePath: MapParsing.asString(map['image_path']),
    );
  }
}