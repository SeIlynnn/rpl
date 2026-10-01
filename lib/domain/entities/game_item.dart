import 'dart:convert';

class GameItem {
  final int? id;
  final int categoryId;
  final String title;
  final String description;
  final String? imagePath;
  final Map<String, dynamic> stats; // For dynamic data like {"Attack": 100, "Element": "Fire"}

  GameItem({
    this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    this.imagePath,
    this.stats = const {},
  });

  factory GameItem.fromJson(Map<String, dynamic> json) {
    return GameItem(
      id: json['id'] as int?,
      categoryId: json['categoryId'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String?,
      stats: json['stats'] != null ? jsonDecode(json['stats'] as String) : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'stats': jsonEncode(stats), // Store as JSON string in SQLite
    };
  }
}
