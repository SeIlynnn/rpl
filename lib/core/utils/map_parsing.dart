class MapParsing {
  static int? asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static List<String> splitTags(String value) {
    if (value.trim().isEmpty) return [];
    return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}