import 'entry_category.dart';

abstract class EncyclopediaEntry {
  int? id;
  String name;
  String? imagePath;

  EncyclopediaEntry({
    this.id,
    required this.name,
    this.imagePath,
  });

  // Wajib ada agar bisa dipakai di repository
  EntryCategory get category;
  Map<String, Object?> toMap();
}