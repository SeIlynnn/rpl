import '../../core/utils/map_parsing.dart';
import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Monster extends EncyclopediaEntry {
  final int? no;
  final int? itemId;
  final String? title;
  final String? habitat;
  final String? classification;
  final String? imunTo;
  final String? itemDrop;
  final String? maxHealth;
  final String? def;
  final String? size;
  final List<String> dropList;

  Monster({
    super.id,
    required super.name,
    super.imagePath,
    this.no,
    this.itemId,
    this.title,
    this.habitat,
    this.classification,
    this.imunTo,
    this.itemDrop,
    this.maxHealth,
    this.def,
    this.size,
    List<String>? dropList,
  }) : dropList = dropList ?? MapParsing.splitTags(itemDrop);

  List<String> get habitatList => MapParsing.splitHabitats(habitat);

  @override
  EntryCategory get category => EntryCategory.monsters;

  @override
  Map<String, Object?> toMap() {
    final drops = itemDrop ?? (dropList.isEmpty ? null : dropList.join(', '));
    return {
      if (id != null) 'id': id,
      'no': no,
      'item_id': itemId,
      'nama': name,
      'title': title,
      'habitat': habitat,
      'classification': classification,
      'imun_to': imunTo,
      'item_drop': drops,
      'max_health': maxHealth,
      'def': def,
      'size': size,
      'image_path': imagePath,
    };
  }

  factory Monster.fromMap(Map<String, Object?> map) {
    final rawDrop = MapParsing.asString(map['item_drop']);
    return Monster(
      id: MapParsing.asInt(map['id']),
      no: MapParsing.asInt(map['no'] ?? map['"no"']),
      itemId: MapParsing.asInt(map['item_id']),
      name: MapParsing.asString(map['nama']) ?? '',
      title: MapParsing.asString(map['title']),
      habitat: MapParsing.asString(map['habitat']),
      classification: MapParsing.asString(map['classification']),
      imunTo: MapParsing.asString(map['imun_to']),
      itemDrop: rawDrop,
      dropList: MapParsing.splitTags(rawDrop),
      maxHealth: MapParsing.asString(map['max_health']),
      def: MapParsing.asString(map['def']),
      size: MapParsing.asString(map['size']),
      imagePath: MapParsing.asString(map['image_path']),
    );
  }
}