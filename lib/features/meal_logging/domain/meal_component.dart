/// A single food component within a [MealLog] or [SavedMeal].
///
/// The `meal_logs.items` and `saved_meals.items` columns store a JSON array
/// of these objects. This class owns the canonical serialization contract for
/// that shape.
///
/// JSON key names follow snake_case to match the Supabase JSONB shape exactly:
/// `{ name, portion, calories, carb_g, protein_g, fat_g, sodium_mg }`.
/// All macro fields are optional — the user may not always have complete data.
class MealComponent {
  const MealComponent({
    required this.name,
    required this.portion,
    this.calories,
    this.carbG,
    this.proteinG,
    this.fatG,
    this.sodiumMg,
  });

  /// Display name of the food item (e.g. "Oatmeal", "Banana").
  final String name;

  /// Human-readable portion description (e.g. "1 cup", "1 medium").
  final String portion;

  /// Calorie count for this portion, if known.
  final int? calories;

  /// Carbohydrate content in grams, if known.
  final double? carbG;

  /// Protein content in grams, if known.
  final double? proteinG;

  /// Fat content in grams, if known.
  final double? fatG;

  /// Sodium content in milligrams, if known.
  final double? sodiumMg;

  // ── Serialization ─────────────────────────────────────────────────────────

  /// Serialize to the canonical JSON shape stored in `meal_logs.items` /
  /// `saved_meals.items`. Sent to Supabase as-is inside a JSONB array.
  Map<String, dynamic> toJson() => {
    'name': name,
    'portion': portion,
    if (calories != null) 'calories': calories,
    if (carbG != null) 'carb_g': carbG,
    if (proteinG != null) 'protein_g': proteinG,
    if (fatG != null) 'fat_g': fatG,
    if (sodiumMg != null) 'sodium_mg': sodiumMg,
  };

  /// Deserialize from the JSON shape stored in `meal_logs.items` /
  /// `saved_meals.items`.
  ///
  /// Silently coerces numeric types to avoid runtime cast errors when Supabase
  /// returns integers for fields declared as REAL (e.g. `carb_g: 30` instead
  /// of `carb_g: 30.0`).
  factory MealComponent.fromJson(Map<String, dynamic> json) {
    return MealComponent(
      name: (json['name'] as String?) ?? '',
      portion: (json['portion'] as String?) ?? '',
      calories: (json['calories'] as num?)?.toInt(),
      carbG: (json['carb_g'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
    );
  }

  MealComponent copyWith({
    String? name,
    String? portion,
    int? calories,
    double? carbG,
    double? proteinG,
    double? fatG,
    double? sodiumMg,
  }) {
    return MealComponent(
      name: name ?? this.name,
      portion: portion ?? this.portion,
      calories: calories ?? this.calories,
      carbG: carbG ?? this.carbG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
    );
  }

  @override
  String toString() =>
      'MealComponent(name: $name, portion: $portion, calories: $calories)';
}
