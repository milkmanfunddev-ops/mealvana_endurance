/// Shared plumbing for the Vana wire records (`contracts.ts`, `contract-v1`).
///
/// Every record in this feature is an immutable, hand-written class with
/// `fromJson`/`toJson`/`copyWith` (the repo does not use freezed — see
/// `meal_logging/domain/meal_log.dart`). Equality is defined once here, in
/// terms of the wire JSON, so each record only has to get `toJson` right.
///
/// Wire keys are **camelCase** — exactly the `contracts.ts` shapes, verified
/// against `test/features/meal_planning/fixtures/*.json`.
library;

/// Base class for wire records: value equality via the JSON projection.
///
/// Trade-off: comparing through `toJson()` costs an allocation per `==`, but
/// these records are small and it guarantees `==` and `toJson` never drift
/// apart (a common bug with hand-maintained equality over nested lists).
abstract class WireRecord {
  const WireRecord();

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WireRecord &&
          other.runtimeType == runtimeType &&
          deepJsonEquals(toJson(), other.toJson()));

  @override
  int get hashCode => Object.hash(runtimeType, deepJsonHash(toJson()));

  @override
  String toString() => '$runtimeType(${toJson()})';
}

// ── Deep JSON equality ───────────────────────────────────────────────────────

/// Structural equality over JSON-ish values (maps, lists, scalars).
///
/// `num` values compare by value so `30` (JSON int) equals `30.0` (a Dart
/// double re-emitted by `toJson`).
bool deepJsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!deepJsonEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

/// Hash consistent with [deepJsonEquals].
int deepJsonHash(Object? value) {
  if (value is Map) {
    // Order-independent: XOR the per-entry hashes.
    var h = 0;
    for (final entry in value.entries) {
      h ^= Object.hash(entry.key, deepJsonHash(entry.value));
    }
    return h;
  }
  if (value is List) return Object.hashAll(value.map(deepJsonHash));
  if (value is num) return value.toDouble().hashCode;
  return value.hashCode;
}

// ── Lenient readers ──────────────────────────────────────────────────────────
//
// Supabase / the edge functions may return `30` for a REAL column or a
// `Map<dynamic, dynamic>` for nested JSON; these coerce rather than cast.

Map<String, dynamic>? asJsonMap(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// Required object — throws [FormatException] when missing or not a map.
Map<String, dynamic> requireJsonMap(Map<String, dynamic> json, String key) {
  final map = asJsonMap(json[key]);
  if (map == null) throw FormatException('Missing object "$key"');
  return map;
}

/// Required string — throws [FormatException] when missing.
String requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Missing string "$key"');
}

String? readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

int? readInt(Map<String, dynamic> json, String key) =>
    (json[key] as num?)?.toInt();

double? readDouble(Map<String, dynamic> json, String key) =>
    (json[key] as num?)?.toDouble();

bool? readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is bool ? value : null;
}

List<String> readStringList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return List.unmodifiable(raw.whereType<String>());
}

List<Map<String, dynamic>> readMapList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (asJsonMap(item) case final map?) map,
  ];
}

/// Parse a list of records, dropping entries the parser rejects
/// (forward-compat: a malformed row never takes the whole payload down).
List<T> readRecordList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final out = <T>[];
  for (final map in readMapList(json, key)) {
    try {
      out.add(parse(map));
    } on FormatException {
      // Skip unparseable entries.
    }
  }
  return List.unmodifiable(out);
}

/// `{ key: value }` string map (e.g. `dayNotes`); non-string values dropped.
Map<String, String> readStringMap(Map<String, dynamic> json, String key) {
  final map = asJsonMap(json[key]);
  if (map == null) return const {};
  return Map.unmodifiable({
    for (final entry in map.entries)
      if (entry.value is String) entry.key: entry.value as String,
  });
}
