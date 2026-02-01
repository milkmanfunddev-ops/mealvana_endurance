/// Type conversion utilities for sync operations between Drift and Supabase.
///
/// Handles the conversion of data types that may come in various formats
/// from different database drivers (SQLite integers, PostgreSQL arrays, etc.)
class SyncTypeConverters {
  SyncTypeConverters._(); // Private constructor - static methods only

  /// Safely convert ID from server (may be int or String) to String.
  /// Handles the transition from BIGINT to UUID schema.
  static String? toStringId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  /// Safely convert required ID (throws if null).
  static String toRequiredStringId(dynamic value, String fieldName) {
    final result = toStringId(value);
    if (result == null) {
      throw ArgumentError('$fieldName cannot be null');
    }
    return result;
  }

  /// Safely convert boolean from server (may be bool, int 0/1, or String).
  /// Handles various representations that different DB drivers might return.
  static bool toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  /// Convert SQLite integer timestamps to ISO8601 strings.
  /// Drift stores DateTimeColumn as milliseconds since epoch in SQLite.
  /// When using customSelect, we get raw int values, not DateTime objects.
  static String? intToIso8601(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return null;
  }

  /// Parse PostgreSQL array format (e.g., "{item1,item2}") to Dart List.
  static List<String>? parsePgArray(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.replaceAll('{', '').replaceAll('}', '');
    if (trimmed.trim().isEmpty) return <String>[];
    return trimmed
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Parse optional DateTime from ISO8601 string.
  static DateTime? parseDateTime(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Parse required DateTime from ISO8601 string.
  static DateTime parseRequiredDateTime(String? value, String fieldName) {
    if (value == null) {
      throw ArgumentError('$fieldName cannot be null');
    }
    final result = DateTime.tryParse(value);
    if (result == null) {
      throw ArgumentError('$fieldName is not a valid ISO8601 date: $value');
    }
    return result;
  }
}
