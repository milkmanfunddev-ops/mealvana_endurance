import 'dart:convert';

/// Meal type for carb loading (breakfast, lunch, dinner, snacks)
/// Maps to meal_types database table
enum MealType {
  breakfast(1, 'breakfast', 'Breakfast'),
  lunch(2, 'lunch', 'Lunch'),
  dinner(3, 'dinner', 'Dinner'),
  snacks(4, 'snacks', 'Snacks'), // Deprecated - use specific snack types
  morningSnack(5, 'morning_snack', 'Morning Snack'),
  afternoonSnack(6, 'afternoon_snack', 'Afternoon Snack'),
  eveningSnack(7, 'evening_snack', 'Evening Snack');

  const MealType(this.id, this.name, this.displayName);

  final int id;
  final String name;
  final String displayName;

  /// Get MealType from database ID
  static MealType fromId(int id) {
    return MealType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => MealType.breakfast,
    );
  }

  /// Get MealType from name string
  static MealType fromName(String name) {
    return MealType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => MealType.breakfast,
    );
  }
}

/// Parse a stored `meal_types` column into MealType ids.
///
/// Canonical implementation — was previously copy-pasted into three files
/// (`food_import_service`, `carb_loading_user_food_repository`,
/// `carb_loading_food_repository`) and had already drifted: two of the copies
/// did a bare `int.parse()`, which **throws** on a name string like
/// 'breakfast'. They survived only because `carb_loading_user_foods` stores ids
/// and has never synced down from Postgres, where the column is `text[]` and
/// `carb_loading_foods` genuinely stores names. This version is the tolerant
/// superset, so it is safe for every caller.
///
/// Handles all the shapes the column actually takes:
///   - Postgres array text:  `{1,2,3}` or `{breakfast,lunch}`
///   - JSON array:           `[1,2,3]` or `["breakfast","lunch"]`
///   - null / empty          -> `[]`
///
/// Unknown names fall back to breakfast (matching [MealType.fromName]) rather
/// than throwing — a bad tag must not break a user's carb loading day.
List<int> parseMealTypeIds(String? raw) {
  if (raw == null || raw.isEmpty) return [];

  int nameOrIdToId(String token) {
    final trimmed = token.trim().replaceAll('"', '');
    if (trimmed.isEmpty) return MealType.breakfast.id;
    // Ints first — that is what the local tables store.
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    return MealType.fromName(trimmed).id;
  }

  try {
    final value = raw.trim();

    // Postgres array literal: {a,b,c}
    if (value.startsWith('{') && value.endsWith('}')) {
      final content = value.substring(1, value.length - 1).trim();
      if (content.isEmpty) return [];
      return content.split(',').map(nameOrIdToId).toList();
    }

    // JSON array: [1,2] or ["breakfast"]
    if (value.startsWith('[') && value.endsWith(']')) {
      final parsed = jsonDecode(value) as List<dynamic>;
      return parsed.map((e) {
        if (e is int) return e;
        if (e is String) return nameOrIdToId(e);
        return MealType.breakfast.id;
      }).toList();
    }

    // Bare single value.
    return [nameOrIdToId(value)];
  } catch (_) {
    // Malformed data must not take the screen down.
    return [];
  }
}
