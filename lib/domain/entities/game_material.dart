import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class GameMaterial extends EncyclopediaEntry {
  final String? itemType;
  final String? itemDrop;
  final String? namaItem;
  final int? rarity;
  final String? objectDrop;

  GameMaterial({
    super.id,
    required super.name,
    super.imagePath,
    this.itemType,
    this.rarity,
    this.itemDrop,
    this.objectDrop,
    this.namaItem,
  });

  @override
  EntryCategory get category => EntryCategory.materials;

  @override
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nama_item': name, // <--- Ubah 'name' jadi 'nama_item' (sesuai DB)
      'image_path': imagePath,
      'rarity': rarity,
      'item_type': itemType, // <--- Ubah 'itemType' jadi 'item_type'
      'item_drop': itemDrop, // <--- Ubah 'itemDrop' jadi 'item_drop'
      'nama_item': namaItem ?? name,
      'object_drop': objectDrop,
    };
  }

  factory GameMaterial.fromMap(Map<String, Object?> map) {
    return GameMaterial(
      id: map['id'] as int?,
      name: map['nama_item'] as String? ?? '', // <--- Ambil dari 'nama_item'
      imagePath: map['image_path'] as String?,
      rarity: map['rarity'] as int?,
      itemType: map['item_type'] as String?, // <--- Ambil dari 'item_type'
      itemDrop: map['item_drop'] as String?, // <--- Ambil dari 'item_drop'
      objectDrop: map['object_drop'] as String?,
      namaItem: map['nama_item'] as String?,
    );
  }
}