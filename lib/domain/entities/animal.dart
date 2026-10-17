import '../../core/utils/map_parsing.dart';
import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Animal extends EncyclopediaEntry {
  final int? no;
  final int? itemId;
  final int? totalHp;
  final String? habitat;
  final String? itemDrop;

  Animal({
    super.id,
    required super.name,
    super.imagePath,
    this.no,
    this.itemId,
    this.totalHp,
    this.habitat,
    this.itemDrop,
  });

  List<String> get dropList => MapParsing.splitTags(itemDrop);
  List<String> get habitatList => MapParsing.splitHabitats(habitat);

  @override
  EntryCategory get category => EntryCategory.animals;

  @override
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'no': no,
      'item_id': itemId,
      'nama': name,
      'total_hp': totalHp,
      'habitat': habitat,
      'item_drop': itemDrop,
      'image_path': imagePath,
    };
  }

  factory Animal.fromMap(Map<String, Object?> map) {
    return Animal(
      id: MapParsing.asInt(map['id']),
      no: MapParsing.asInt(map['no']),
      itemId: MapParsing.asInt(map['item_id']),
      name: MapParsing.asString(map['nama']) ?? '',
      totalHp: MapParsing.asInt(map['total_hp']),
      habitat: MapParsing.asString(map['habitat']),
      itemDrop: MapParsing.asString(map['item_drop']),
      imagePath: MapParsing.asString(map['image_path']),
    );
  }
}