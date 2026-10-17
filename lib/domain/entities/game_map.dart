import '../../core/utils/map_parsing.dart';
import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class GameMap extends EncyclopediaEntry {
  final int? no;
  final int? itemId;
  final String? deskripsi;

  GameMap({
    super.id,
    required super.name,
    super.imagePath,
    this.no,
    this.itemId,
    this.deskripsi,
  });

  @override
  EntryCategory get category => EntryCategory.maps;

  @override
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'no': no,
      'item_id': itemId,
      'nama': name,
      'deskripsi': deskripsi,
      'image_path': imagePath,
    };
  }

  factory GameMap.fromMap(Map<String, Object?> map) {
    return GameMap(
      id: MapParsing.asInt(map['id']),
      no: MapParsing.asInt(map['no']),
      itemId: MapParsing.asInt(map['item_id']),
      name: MapParsing.asString(map['nama']) ?? '',
      deskripsi: MapParsing.asString(map['deskripsi']),
      imagePath: MapParsing.asString(map['image_path']),
    );
  }
}
