/// Lenient converters used when mapping SQLite rows / seed JSON into entities.
///
/// SQLite and JSON can hand back numbers as `int`, `double` or even `String`,
/// so every entity goes through these helpers instead of hard casts.
abstract final class MapParsing {
  static int? asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
    }
    return null;
  }

  static double? asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  /// Returns a trimmed string, or `null` when the value is missing/blank.
  static String? asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Splits comma separated cells such as `"Burning,Poison"` into clean tags.
  static List<String> splitTags(String? value) {
    if (value == null) return const [];
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty && tag.toLowerCase() != 'none')
        .toList(growable: false);
  }

  /// Splits habitat strings separated by `,` or `&` such as `"Luminer Cave & Lumera Lands"`.
  static List<String> splitHabitats(String? value) {
    if (value == null) return const [];
    return value
        .split(RegExp(r'[,&]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty && tag.toLowerCase() != 'none')
        .toList(growable: false);
  }
}