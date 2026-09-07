import 'dart:convert';

/// Decode a db JSON-array string (`'["dairy","gluten"]'`) into a string
/// list; malformed or non-list input decodes to empty.
List<String> decodeDbStringArray(String raw) {
  try {
    final v = jsonDecode(raw);
    return v is List
        ? v.map((e) => e.toString()).toList(growable: false)
        : const [];
  } catch (_) {
    return const [];
  }
}
