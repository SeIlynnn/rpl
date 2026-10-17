import '../../core/utils/map_parsing.dart';
import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class GameMaterial extends EncyclopediaEntry {
  final int? no;
  final int? itemId;
  final String? namaItem;
  final int? rarity;
  final String? itemType;
  final String? itemDrop;
  final String? objectDrop;
  final double? persentase;

  GameMaterial({
    super.id,
    required super.name,
    super.imagePath,
    this.no,
    this.itemId,
    this.namaItem,
    this.rarity,
    this.itemType,
    this.itemDrop,
    this.objectDrop,
    this.persentase,
  });

  @override
  EntryCategory get category => EntryCategory.materials;

  @override
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'no': no,
      'item_id': itemId,
      'nama_item': namaItem ?? name,
      'rarity': rarity,
      'item_type': itemType,
      'item_drop': itemDrop,
      'object_drop': objectDrop,
      'persentase': persentase,
      'image_path': imagePath,
    };
  }

  factory GameMaterial.fromMap(Map<String, Object?> map) {
    final nama = MapParsing.asString(map['nama_item']) ?? '';
    return GameMaterial(
      id: MapParsing.asInt(map['id']),
      no: MapParsing.asInt(map['no']),
      itemId: MapParsing.asInt(map['item_id']),
      name: nama,
      namaItem: nama,
      rarity: MapParsing.asInt(map['rarity']),
      itemType: MapParsing.asString(map['item_type']),
      itemDrop: MapParsing.asString(map['item_drop']),
      objectDrop: MapParsing.asString(map['object_drop']),
      persentase: MapParsing.asDouble(map['persentase']),
      imagePath: MapParsing.asString(map['image_path']),
    );
  }
}