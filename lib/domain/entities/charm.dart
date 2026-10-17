import '../../core/utils/map_parsing.dart';
import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Charm extends EncyclopediaEntry {
  final int? no;
  final int? itemId;
  final int? rarity;
  final String? stats;

  Charm({
    super.id,
    required super.name,
    super.imagePath,
    this.no,
    this.itemId,
    this.rarity,
    this.stats,
  });

  @override
  EntryCategory get category => EntryCategory.charms;

  @override
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'no': no,
      'item_id': itemId,
      'nama_item': name,
      'rarity': rarity,
      'stats': stats,
      'image_path': imagePath,
    };
  }

  factory Charm.fromMap(Map<String, Object?> map) {
    return Charm(
      id: MapParsing.asInt(map['id']),
      no: MapParsing.asInt(map['no']),
      itemId: MapParsing.asInt(map['item_id']),
      name: MapParsing.asString(map['nama_item']) ?? '',
      rarity: MapParsing.asInt(map['rarity']),
      stats: MapParsing.asString(map['stats']),
      imagePath: MapParsing.asString(map['image_path']),
    );
  }
}