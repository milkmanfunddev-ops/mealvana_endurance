/// Macro summary for nutrition plan display
class PlanMacroSummary {
  const PlanMacroSummary({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.sodium,
    this.sodiumMin,
    this.sodiumMax,
    this.fluids,
    this.fluidsMin,
    this.fluidsMax,
    this.carbsRange,
    this.proteinRange,
    this.fatRange,
  });

  final int calories;
  final int carbs; // grams
  final int protein; // grams
  final int fat; // grams
  final int? sodium; // mg (average)
  final int? sodiumMin; // mg (minimum)
  final int? sodiumMax; // mg (maximum)
  final int? fluids; // oz (average)
  final int? fluidsMin; // oz (minimum)
  final int? fluidsMax; // oz (maximum)
  final String? carbsRange; // e.g., "45-65%"
  final String? proteinRange; // e.g., "10-15%"
  final String? fatRange; // e.g., "20-35%"

  /// Create PlanMacroSummary from JSON
  factory PlanMacroSummary.fromJson(Map<String, dynamic> json) {
    return PlanMacroSummary(
      calories: json['calories'] as int,
      carbs: json['carbs'] as int,
      protein: json['protein'] as int,
      fat: json['fat'] as int,
      sodium: json['sodium'] as int?,
      sodiumMin: json['sodiumMin'] as int?,
      sodiumMax: json['sodiumMax'] as int?,
      fluids: json['fluids'] as int?,
      fluidsMin: json['fluidsMin'] as int?,
      fluidsMax: json['fluidsMax'] as int?,
      carbsRange: json['carbsRange'] as String?,
      proteinRange: json['proteinRange'] as String?,
      fatRange: json['fatRange'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'sodium': sodium,
      'sodiumMin': sodiumMin,
      'sodiumMax': sodiumMax,
      'fluids': fluids,
      'fluidsMin': fluidsMin,
      'fluidsMax': fluidsMax,
      'carbsRange': carbsRange,
      'proteinRange': proteinRange,
      'fatRange': fatRange,
    };
  }

  PlanMacroSummary copyWith({
    int? calories,
    int? carbs,
    int? protein,
    int? fat,
    int? sodium,
    int? sodiumMin,
    int? sodiumMax,
    int? fluids,
    int? fluidsMin,
    int? fluidsMax,
    String? carbsRange,
    String? proteinRange,
    String? fatRange,
  }) {
    return PlanMacroSummary(
      calories: calories ?? this.calories,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      sodium: sodium ?? this.sodium,
      sodiumMin: sodiumMin ?? this.sodiumMin,
      sodiumMax: sodiumMax ?? this.sodiumMax,
      fluids: fluids ?? this.fluids,
      fluidsMin: fluidsMin ?? this.fluidsMin,
      fluidsMax: fluidsMax ?? this.fluidsMax,
      carbsRange: carbsRange ?? this.carbsRange,
      proteinRange: proteinRange ?? this.proteinRange,
      fatRange: fatRange ?? this.fatRange,
    );
  }

  @override
  String toString() =>
      'PlanMacroSummary(cal: $calories, carbs: ${carbs}g, protein: ${protein}g, fat: ${fat}g)';
}
