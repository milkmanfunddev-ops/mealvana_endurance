/// Common food allergens for user allergy tracking
///
/// Used during onboarding to filter foods containing allergens.
/// Multi-select (user can have multiple allergies).
enum Allergy {
  dairy,
  eggs,
  fish,
  gluten,
  peanuts,
  sesame,
  shellfish,
  soy,
  treeNuts;

  /// Database value (snake_case for PostgreSQL enum)
  String get dbValue {
    switch (this) {
      case Allergy.treeNuts:
        return 'tree_nuts';
      default:
        return name;
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case Allergy.dairy:
        return 'Dairy';
      case Allergy.eggs:
        return 'Eggs';
      case Allergy.fish:
        return 'Fish';
      case Allergy.gluten:
        return 'Gluten';
      case Allergy.peanuts:
        return 'Peanuts';
      case Allergy.sesame:
        return 'Sesame';
      case Allergy.shellfish:
        return 'Shellfish';
      case Allergy.soy:
        return 'Soy';
      case Allergy.treeNuts:
        return 'Tree nuts';
    }
  }

  /// Create from database value
  static Allergy? fromDbValue(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'dairy':
        return Allergy.dairy;
      case 'eggs':
        return Allergy.eggs;
      case 'fish':
        return Allergy.fish;
      case 'gluten':
        return Allergy.gluten;
      case 'peanuts':
        return Allergy.peanuts;
      case 'sesame':
        return Allergy.sesame;
      case 'shellfish':
        return Allergy.shellfish;
      case 'soy':
        return Allergy.soy;
      case 'tree_nuts':
        return Allergy.treeNuts;
      default:
        return null;
    }
  }

  /// Parse a list of allergies from database array format
  /// Handles PostgreSQL array format {a,b,c} and JSON format ["a","b"]
  static List<Allergy> fromDbArray(String? value) {
    if (value == null || value.isEmpty || value == '{}') {
      return [];
    }

    final trimmed = value.trim();
    List<String> allergyStrings = [];

    // Handle PostgreSQL array format: {dairy,gluten,peanuts}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isNotEmpty) {
        allergyStrings = inner.split(',').map((s) => s.trim()).toList();
      }
    }
    // Handle JSON array format: ["dairy","gluten"]
    else if (trimmed.startsWith('[')) {
      // Simple JSON parsing without importing dart:convert
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isNotEmpty) {
        allergyStrings = inner
            .split(',')
            .map((s) => s.trim().replaceAll('"', ''))
            .toList();
      }
    }
    // Fallback: comma-separated or single value
    else if (trimmed.contains(',')) {
      allergyStrings = trimmed.split(',').map((s) => s.trim()).toList();
    } else if (trimmed.isNotEmpty) {
      allergyStrings = [trimmed];
    }

    // Convert strings to Allergy enums
    return allergyStrings
        .map((str) => Allergy.fromDbValue(str))
        .whereType<Allergy>()
        .toList();
  }

  /// Parse a list of allergies from a native Dart list.
  /// Used when Supabase returns PostgreSQL arrays as List.
  static List<Allergy> fromList(List<dynamic> values) {
    return values
        .map((v) => Allergy.fromDbValue(v?.toString()))
        .whereType<Allergy>()
        .toList();
  }

  /// Convert list of allergies to database array format
  static String toDbArray(List<Allergy> allergies) {
    if (allergies.isEmpty) return '{}';
    return '{${allergies.map((a) => a.dbValue).join(',')}}';
  }

  /// Convert list of allergies to a plain JSON array of dbValue strings.
  ///
  /// Use this when sending to Supabase (column `users.allergies` is
  /// `allergy_enum[]`). PostgREST cannot cast a JSON string like `"{dairy}"`
  /// into an enum array — it needs a real JSON array `["dairy"]`. The
  /// PG-literal `toDbArray` form is correct for local Drift writes only.
  static List<String> toJsonList(List<Allergy> allergies) {
    return allergies.map((a) => a.dbValue).toList();
  }

  /// All values for UI display
  static List<Allergy> get allValues => Allergy.values;
}
