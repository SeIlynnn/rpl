class GameCategory {
  final int? id;
  final String name;
  final String? iconPath;

  GameCategory({
    this.id,
    required this.name,
    this.iconPath,
  });

  factory GameCategory.fromJson(Map<String, dynamic> json) {
    return GameCategory(
      id: json['id'] as int?,
      name: json['name'] as String,
      iconPath: json['iconPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconPath': iconPath,
    };
  }
}
