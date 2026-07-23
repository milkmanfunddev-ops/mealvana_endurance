/// User dietary preference options for food filtering
///
/// Used during onboarding to filter foods that don't match the user's diet.
/// Single-select (user can only have one dietary preference).
enum DietaryPreference {
  none,
  omnivore,
  vegetarian,
  pescatarian,
  vegan,
  mediterranean,
  paleo,
  keto,
  lowCarb;

  /// Database value (snake_case for PostgreSQL enum)
  String get dbValue {
    switch (this) {
      case DietaryPreference.lowCarb:
        return 'low_carb';
      default:
        return name;
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case DietaryPreference.none:
        return 'No Preference';
      case DietaryPreference.omnivore:
        return 'Omnivore';
      case DietaryPreference.vegetarian:
        return 'Vegetarian';
      case DietaryPreference.pescatarian:
        return 'Pescatarian';
      case DietaryPreference.vegan:
        return 'Vegan';
      case DietaryPreference.mediterranean:
        return 'Mediterranean';
      case DietaryPreference.paleo:
        return 'Paleo';
      case DietaryPreference.keto:
        return 'Keto';
      case DietaryPreference.lowCarb:
        return 'Low-Carb';
    }
  }

  /// Create from database value
  static DietaryPreference? fromDbValue(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'omnivore':
        return DietaryPreference.omnivore;
      case 'vegetarian':
        return DietaryPreference.vegetarian;
      case 'pescatarian':
        return DietaryPreference.pescatarian;
      case 'vegan':
        return DietaryPreference.vegan;
      case 'mediterranean':
        return DietaryPreference.mediterranean;
      case 'paleo':
        return DietaryPreference.paleo;
      case 'keto':
        return DietaryPreference.keto;
      case 'low_carb':
        return DietaryPreference.lowCarb;
      default:
        return null;
    }
  }

  /// Parse a list of dietary preferences from database array format
  /// Handles PostgreSQL array format {a,b,c} and JSON format ["a","b"]
  static List<DietaryPreference> fromDbArray(String? value) {
    if (value == null || value.isEmpty || value == '{}') {
      return [];
    }

    final trimmed = value.trim();
    List<String> dietStrings = [];

    // Handle PostgreSQL array format: {vegan,paleo,keto}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isNotEmpty) {
        dietStrings = inner.split(',').map((s) => s.trim()).toList();
      }
    }
    // Handle JSON array format: ["vegan","paleo"]
    else if (trimmed.startsWith('[')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isNotEmpty) {
        dietStrings = inner
            .split(',')
            .map((s) => s.trim().replaceAll('"', ''))
            .toList();
      }
    }
    // Fallback: comma-separated or single value
    else if (trimmed.contains(',')) {
      dietStrings = trimmed.split(',').map((s) => s.trim()).toList();
    } else if (trimmed.isNotEmpty) {
      dietStrings = [trimmed];
    }

    // Convert strings to DietaryPreference enums
    return dietStrings
        .map((str) => DietaryPreference.fromDbValue(str))
        .whereType<DietaryPreference>()
        .toList();
  }

  /// Parse a list of dietary preferences from a native Dart list.
  /// Used when Supabase returns PostgreSQL arrays as List.
  static List<DietaryPreference> fromList(List<dynamic> values) {
    return values
        .map((v) => DietaryPreference.fromDbValue(v?.toString()))
        .whereType<DietaryPreference>()
        .toList();
  }

  /// Convert list of dietary preferences to database array format
  static String toDbArray(List<DietaryPreference> diets) {
    if (diets.isEmpty) return '{}';
    return '{${diets.map((d) => d.dbValue).join(',')}}';
  }

  /// All values for UI display (excludes 'none' - users should select 'omnivore' instead)
  static List<DietaryPreference> get allValues => DietaryPreference.values
      .where((d) => d != DietaryPreference.none)
      .toList();

  /// All values ordered for onboarding display (omnivore first as recommended default)
  static List<DietaryPreference> get orderedForOnboarding => [
    DietaryPreference.omnivore,
    DietaryPreference.vegetarian,
    DietaryPreference.pescatarian,
    DietaryPreference.vegan,
    DietaryPreference.mediterranean,
    DietaryPreference.paleo,
    DietaryPreference.keto,
    DietaryPreference.lowCarb,
  ];
}
