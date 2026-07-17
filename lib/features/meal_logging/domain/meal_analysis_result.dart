import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';

/// A single identified food item within a [MealAnalysisResult].
///
/// Shape mirrors the `MealItemSchema` in
/// `supabase/functions/_shared/meal_analysis/schema.ts`.
class MealAnalysisItem {
  const MealAnalysisItem({
    required this.name,
    required this.portion,
    required this.calories,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
  });

  final String name;

  /// Human-readable portion description, e.g. "1 cup" or "3 oz".
  final String portion;

  final int calories;
  final double carbG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;

  factory MealAnalysisItem.fromJson(Map<String, dynamic> json) {
    return MealAnalysisItem(
      name: json['name'] as String,
      portion: json['portion'] as String,
      calories: (json['calories'] as num).toInt(),
      carbG: (json['carb_g'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      sodiumMg: (json['sodium_mg'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'portion': portion,
    'calories': calories,
    'carb_g': carbG,
    'protein_g': proteinG,
    'fat_g': fatG,
    'sodium_mg': sodiumMg,
  };
}

/// Summed macros for all items in a [MealAnalysisResult].
class MealAnalysisTotals {
  const MealAnalysisTotals({
    required this.calories,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
  });

  final int calories;
  final double carbG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;

  factory MealAnalysisTotals.fromJson(Map<String, dynamic> json) {
    return MealAnalysisTotals(
      calories: (json['calories'] as num).toInt(),
      carbG: (json['carb_g'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      sodiumMg: (json['sodium_mg'] as num).toDouble(),
    );
  }
}

/// Model confidence in the identification and macro estimates.
enum MealAnalysisConfidence {
  low,
  medium,
  high;

  static MealAnalysisConfidence fromString(String value) {
    switch (value) {
      case 'low':
        return MealAnalysisConfidence.low;
      case 'medium':
        return MealAnalysisConfidence.medium;
      case 'high':
        return MealAnalysisConfidence.high;
      default:
        return MealAnalysisConfidence.medium;
    }
  }
}

/// The structured result returned by either Jade edge function
/// (`analyze-meal-photo` or `describe-meal`).
///
/// Shape mirrors `MealAnalysis` in
/// `supabase/functions/_shared/meal_analysis/schema.ts`.
class MealAnalysisResult {
  const MealAnalysisResult({
    required this.name,
    required this.suggestedSlot,
    required this.confidence,
    required this.items,
    required this.totals,
    this.notes,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.model,
    this.costUsd,
  });

  /// Short descriptive title, e.g. "Grilled chicken with rice and salad".
  final String name;

  /// Model's best-guess meal slot.
  final MealSlot suggestedSlot;

  /// Model's self-reported confidence in the result.
  final MealAnalysisConfidence confidence;

  /// Individual food items identified.
  final List<MealAnalysisItem> items;

  /// Pre-computed sum of all item macros.
  final MealAnalysisTotals totals;

  /// Optional one-line caveat for the user.
  final String? notes;

  /// Actual model usage returned by the edge function for analytics.
  final int inputTokens;
  final int outputTokens;
  final String? model;

  /// Actual USD charge reported by AI Gateway, when available.
  final double? costUsd;

  int get totalTokens => inputTokens + outputTokens;

  factory MealAnalysisResult.fromJson(Map<String, dynamic> json) {
    final slotRaw = json['suggested_slot'] as String?;
    final slot = MealSlot.fromWireValue(slotRaw) ?? MealSlot.snack;

    final itemsRaw = json['items'] as List<dynamic>;
    final items = itemsRaw
        .cast<Map<String, dynamic>>()
        .map(MealAnalysisItem.fromJson)
        .toList();

    final usage = json['_usage'];
    final usageMap = usage is Map ? usage : const <String, dynamic>{};

    return MealAnalysisResult(
      name: json['name'] as String,
      suggestedSlot: slot,
      confidence: MealAnalysisConfidence.fromString(
        json['confidence'] as String? ?? 'medium',
      ),
      items: items,
      totals: MealAnalysisTotals.fromJson(
        json['totals'] as Map<String, dynamic>,
      ),
      notes: json['notes'] as String?,
      inputTokens: (usageMap['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usageMap['output_tokens'] as num?)?.toInt() ?? 0,
      model: usageMap['model'] as String?,
      costUsd: (usageMap['cost_usd'] as num?)?.toDouble(),
    );
  }
}
