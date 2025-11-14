import 'food_item.dart';

/// Simplified nutrition data for an activity
///
/// Replaces the complex NutritionPlan model with a lightweight data structure.
/// No repository, no global state - just nutrition data owned by an Activity.
class NutritionData {
  const NutritionData({
    required this.beforeRunFoods,
    required this.duringRunFoods,
    required this.afterRunFoods,
    required this.macroTargets,
  });

  final List<FoodItem> beforeRunFoods;
  final List<FoodItem> duringRunFoods;
  final List<FoodItem> afterRunFoods;
  final MacroTargets macroTargets;

  /// Create from JSON (from Edge Function or database)
  factory NutritionData.fromJson(Map<String, dynamic> json) {
    return NutritionData(
      beforeRunFoods: (json['beforeRunFoods'] as List? ?? [])
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      duringRunFoods: (json['duringRunFoods'] as List? ?? [])
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      afterRunFoods: (json['afterRunFoods'] as List? ?? [])
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      macroTargets: MacroTargets.fromJson(json['macroTargets'] as Map<String, dynamic>),
    );
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'beforeRunFoods': beforeRunFoods.map((e) => e.toJson()).toList(),
      'duringRunFoods': duringRunFoods.map((e) => e.toJson()).toList(),
      'afterRunFoods': afterRunFoods.map((e) => e.toJson()).toList(),
      'macroTargets': macroTargets.toJson(),
    };
  }

  /// Create a copy with updated values
  NutritionData copyWith({
    List<FoodItem>? beforeRunFoods,
    List<FoodItem>? duringRunFoods,
    List<FoodItem>? afterRunFoods,
    MacroTargets? macroTargets,
  }) {
    return NutritionData(
      beforeRunFoods: beforeRunFoods ?? this.beforeRunFoods,
      duringRunFoods: duringRunFoods ?? this.duringRunFoods,
      afterRunFoods: afterRunFoods ?? this.afterRunFoods,
      macroTargets: macroTargets ?? this.macroTargets,
    );
  }

  /// Get all foods across all phases
  List<FoodItem> get allFoods => [
    ...beforeRunFoods,
    ...duringRunFoods,
    ...afterRunFoods,
  ];

  /// Get total calories across all phases
  int get totalCalories {
    return allFoods.fold<int>(
      0,
      (sum, food) => sum + (food.calories ?? 0),
    );
  }

  /// Get total carbs across all phases
  double get totalCarbsGrams {
    return allFoods.fold<double>(
      0.0,
      (sum, food) => sum + (food.carbsGrams ?? 0.0),
    );
  }

  /// Get total protein across all phases
  double get totalProteinGrams {
    return allFoods.fold<double>(
      0.0,
      (sum, food) => sum + (food.proteinGrams ?? 0.0),
    );
  }

  /// Get total fat across all phases
  double get totalFatGrams {
    return allFoods.fold<double>(
      0.0,
      (sum, food) => sum + (food.fatGrams ?? 0.0),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NutritionData &&
        _listEquals(other.beforeRunFoods, beforeRunFoods) &&
        _listEquals(other.duringRunFoods, duringRunFoods) &&
        _listEquals(other.afterRunFoods, afterRunFoods) &&
        other.macroTargets == macroTargets;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(beforeRunFoods),
    Object.hashAll(duringRunFoods),
    Object.hashAll(afterRunFoods),
    macroTargets,
  );

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'NutritionData(foods: ${allFoods.length}, macros: $macroTargets)';
}

/// Macro nutrient targets for nutrition data
class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.carbsGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.sodiumMg,
    required this.fluidsMl,
  });

  final int calories;
  final int carbsGrams;
  final int proteinGrams;
  final int fatGrams;
  final int sodiumMg;
  final int fluidsMl;

  /// Create from JSON
  factory MacroTargets.fromJson(Map<String, dynamic> json) {
    return MacroTargets(
      calories: json['calories'] as int? ?? 0,
      carbsGrams: json['carbsGrams'] as int? ?? 0,
      proteinGrams: json['proteinGrams'] as int? ?? 0,
      fatGrams: json['fatGrams'] as int? ?? 0,
      sodiumMg: json['sodiumMg'] as int? ?? 0,
      fluidsMl: json['fluidsMl'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'carbsGrams': carbsGrams,
      'proteinGrams': proteinGrams,
      'fatGrams': fatGrams,
      'sodiumMg': sodiumMg,
      'fluidsMl': fluidsMl,
    };
  }

  /// Create a copy with updated values
  MacroTargets copyWith({
    int? calories,
    int? carbsGrams,
    int? proteinGrams,
    int? fatGrams,
    int? sodiumMg,
    int? fluidsMl,
  }) {
    return MacroTargets(
      calories: calories ?? this.calories,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      fluidsMl: fluidsMl ?? this.fluidsMl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MacroTargets &&
        other.calories == calories &&
        other.carbsGrams == carbsGrams &&
        other.proteinGrams == proteinGrams &&
        other.fatGrams == fatGrams &&
        other.sodiumMg == sodiumMg &&
        other.fluidsMl == fluidsMl;
  }

  @override
  int get hashCode => Object.hash(
    calories,
    carbsGrams,
    proteinGrams,
    fatGrams,
    sodiumMg,
    fluidsMl,
  );

  @override
  String toString() =>
      'MacroTargets(cal: $calories, carbs: ${carbsGrams}g, protein: ${proteinGrams}g, fat: ${fatGrams}g, sodium: ${sodiumMg}mg, fluids: ${fluidsMl}ml)';
}
