import 'encyclopedia_entry.dart';
import 'entry_category.dart';

class Monster extends EncyclopediaEntry {
  final String? title;
  final String? classification;
  final String? habitat;
  final String? size;
  final List<String> dropList;
  final int? no;

  Monster({
    super.id,
    required super.name,
    super.imagePath,
    this.title,
    this.classification,
    this.habitat,
    this.size,
    this.dropList = const [],
    this.no,
  });

  @override
  EntryCategory get category => EntryCategory.monsters;

  @override
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nama': name, // <--- Ubah 'name' jadi 'nama' (sesuai DB)
      'image_path': imagePath,
      'title': title,
      'classification': classification,
      'habitat': habitat,
      'size': size,
      'item_drop': dropList.join(', '), // <--- Ubah 'dropList' jadi 'item_drop' (gabung jadi string)
      '"no"': no, // <--- Pakai tanda kutip ganda sesuai DB
    };
  }

  factory Monster.fromMap(Map<String, Object?> map) {
    return Monster(
      id: map['id'] as int?,
      name: map['nama'] as String? ?? '', // <--- Ambil dari 'nama'
      imagePath: map['image_path'] as String?,
      title: map['title'] as String?,
      classification: map['classification'] as String?,
      habitat: map['habitat'] as String?,
      size: map['size'] as String?,
      dropList: (map['item_drop'] as String?)?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [], // <--- Ambil dari 'item_drop'
      no: map['no'] as int?,
    );
  }
}