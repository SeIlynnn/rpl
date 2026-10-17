import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Animal extends EncyclopediaEntry {
  final int? totalHp;
  final String? habitat;
  final String? itemDrop;

  Animal({
    super.id,
    required super.name,
    super.imagePath,
    this.totalHp,
    this.habitat,
    this.itemDrop,
  });

  @override
  EntryCategory get category => EntryCategory.animals;

  @override
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nama': name,
      'image_path': imagePath,
      'total_hp': totalHp,
      'habitat': habitat,
      'item_drop': itemDrop,
    };
  }

  factory Animal.fromMap(Map<String, Object?> map) {
    return Animal(
      id: map['id'] as int?,
      name: map['nama'] as String? ?? '',
      imagePath: map['image_path'] as String?,
      totalHp: map['total_hp'] as int?,
      habitat: map['habitat'] as String?,
      itemDrop: map['item_drop'] as String?,
    );
  }
}