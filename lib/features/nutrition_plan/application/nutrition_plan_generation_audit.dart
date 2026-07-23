import '../domain/food_item_data.dart';
import '../domain/macro_shortfall.dart';
import '../domain/macro_target_status.dart';
import '../domain/nutrition_plan.dart';

enum AuditedNutrient {
  carbs('carbs', 'g', ShortfallMacro.carbs),
  protein('protein', 'g', ShortfallMacro.protein),
  sodium('sodium', 'mg', ShortfallMacro.sodium),
  fluids('fluids', 'mL', ShortfallMacro.fluid);

  const AuditedNutrient(this.label, this.unit, this.shortfallMacro);

  final String label;
  final String unit;
  final ShortfallMacro shortfallMacro;
}

class NutritionPlanTargetMiss {
  const NutritionPlanTargetMiss({
    required this.sectionId,
    required this.nutrient,
    required this.actual,
    required this.target,
    required this.status,
    this.low,
    this.high,
  });

  final String sectionId;
  final AuditedNutrient nutrient;
  final int actual;
  final int target;
  final int? low;
  final int? high;
  final MacroTargetStatus status;

  Map<String, Object?> toJson() => {
    'section': sectionId,
    'nutrient': nutrient.label,
    'actual': actual,
    'target': target,
    'unit': nutrient.unit,
    if (low != null) 'low': low,
    if (high != null) 'high': high,
    'status': status.name,
  };
}

class NutritionPlanGenerationAudit {
  const NutritionPlanGenerationAudit._();

  static List<NutritionPlanTargetMiss> findUnexplainedMisses(
    NutritionPlan plan,
  ) {
    final misses = <NutritionPlanTargetMiss>[];

    for (final section in plan.sections) {
      if (_isAfterSection(section)) continue;

      final foods = section.hasSubPhases
          ? section.subPhases!.expand((subPhase) => subPhase.foodItems).toList()
          : section.foodItems;
      final totals = _totals(foods);
      final expectedShortfalls = <ShortfallMacro>{
        ...section.shortfalls.map((shortfall) => shortfall.macro),
        if (section.hasSubPhases)
          ...section.subPhases!.expand(
            (subPhase) =>
                subPhase.shortfalls.map((shortfall) => shortfall.macro),
          ),
      };

      final targets = section.hasSubPhases
          ? _aggregateBeforeTargets(section)
          : _SectionTargets.fromSection(section);

      _addMiss(
        misses,
        sectionId: section.id,
        nutrient: AuditedNutrient.carbs,
        actual: totals.carbs,
        target: targets.carbs,
        low: section.carbsLowTarget?.round(),
        high: section.carbsHighTarget?.round(),
        expectedShortfalls: expectedShortfalls,
      );
      _addMiss(
        misses,
        sectionId: section.id,
        nutrient: AuditedNutrient.protein,
        actual: totals.protein,
        target: targets.protein,
        low: section.proteinLowTarget?.round(),
        high: section.proteinHighTarget?.round(),
        expectedShortfalls: expectedShortfalls,
      );
      _addMiss(
        misses,
        sectionId: section.id,
        nutrient: AuditedNutrient.sodium,
        actual: totals.sodium,
        target: targets.sodium,
        low: section.sodiumLowTarget?.round(),
        high: section.sodiumHighTarget?.round(),
        expectedShortfalls: expectedShortfalls,
      );
      _addMiss(
        misses,
        sectionId: section.id,
        nutrient: AuditedNutrient.fluids,
        actual: totals.fluids,
        target: targets.fluids,
        low: section.fluidsLowTarget?.round(),
        high: section.fluidsHighTarget?.round(),
        expectedShortfalls: expectedShortfalls,
      );
    }

    return misses;
  }

  static bool _isAfterSection(PlanSection section) {
    final id = section.id.toLowerCase();
    final title = section.title.toLowerCase();
    return id.startsWith('after') || title.startsWith('after');
  }

  static _SectionTargets _aggregateBeforeTargets(PlanSection section) {
    var carbs = 0;
    var protein = 0;
    var sodium = 0;
    var fluids = 0;

    for (final subPhase in section.subPhases!) {
      carbs += subPhase.carbsTarget?.round() ?? 0;
      protein += subPhase.proteinTarget?.round() ?? 0;
      sodium += subPhase.sodiumTarget?.round() ?? 0;
      fluids += subPhase.fluidsTarget?.round() ?? 0;
    }

    return _SectionTargets(
      carbs: carbs,
      protein: protein,
      sodium: sodium,
      fluids: fluids,
    );
  }

  static _NutritionTotals _totals(List<FoodItemData> foods) {
    var carbs = 0;
    var protein = 0;
    var sodium = 0;
    var fluids = 0.0;

    for (final food in foods) {
      final nutrition = food.nutritionalInfo;
      if (nutrition == null) continue;
      carbs += nutrition.carbs ?? 0;
      protein += nutrition.protein ?? 0;
      sodium += nutrition.sodium ?? 0;
      fluids += nutrition.fluids ?? 0;
    }

    return _NutritionTotals(
      carbs: carbs,
      protein: protein,
      sodium: sodium,
      fluids: fluids.round(),
    );
  }

  static void _addMiss(
    List<NutritionPlanTargetMiss> misses, {
    required String sectionId,
    required AuditedNutrient nutrient,
    required int actual,
    required int target,
    required Set<ShortfallMacro> expectedShortfalls,
    int? low,
    int? high,
  }) {
    if (target <= 0 || expectedShortfalls.contains(nutrient.shortfallMacro)) {
      return;
    }

    final status = classifyMacroTarget(
      actual: actual,
      target: target,
      low: low,
      high: high,
    );
    if (status == MacroTargetStatus.green) return;

    misses.add(
      NutritionPlanTargetMiss(
        sectionId: sectionId,
        nutrient: nutrient,
        actual: actual,
        target: target,
        low: low,
        high: high,
        status: status,
      ),
    );
  }
}

class _NutritionTotals {
  const _NutritionTotals({
    required this.carbs,
    required this.protein,
    required this.sodium,
    required this.fluids,
  });

  final int carbs;
  final int protein;
  final int sodium;
  final int fluids;
}

class _SectionTargets {
  const _SectionTargets({
    required this.carbs,
    required this.protein,
    required this.sodium,
    required this.fluids,
  });

  factory _SectionTargets.fromSection(PlanSection section) {
    return _SectionTargets(
      carbs: section.carbsTarget?.round() ?? 0,
      protein: section.proteinTarget?.round() ?? 0,
      sodium: section.sodiumTarget?.round() ?? 0,
      fluids: section.fluidsTarget?.round() ?? 0,
    );
  }

  final int carbs;
  final int protein;
  final int sodium;
  final int fluids;
}
