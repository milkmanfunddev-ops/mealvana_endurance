import 'dart:math';

import '../../../features/nutrition_plan/domain/nutrition_plan.dart';
import '../../../features/nutrition_plan/domain/food_item_data.dart';
import '../../../features/nutrition_plan/domain/macro_targets.dart';

/// Service for scaling template nutrition plans to match new macro targets
class TemplateScalingService {
  /// Scale a nutrition plan's food quantities to match new macro targets
  ///
  /// Uses per-phase carb ratio for scaling (carbs are the primary macro
  /// for endurance nutrition). All foods in a phase are scaled by the
  /// same ratio to keep food proportions intact.
  ///
  /// Falls back to total-carb scaling when per-phase targets aren't available.
  static NutritionPlan scalePlanWithTargets({
    required NutritionPlan plan,
    required MacroTargets targets,
  }) {
    final scaledSections = <PlanSection>[];

    for (final section in plan.sections) {
      final sectionCarbs = _sectionCarbTotal(section);
      final targetCarbs = _getTargetCarbsForSection(section.id, targets);

      if (targetCarbs == null || targetCarbs <= 0 || sectionCarbs <= 0) {
        scaledSections.add(section);
        continue;
      }

      var ratio = targetCarbs / sectionCarbs;

      // Cap ratio to prevent extreme scaling (0.5x to 2.0x)
      ratio = max(0.5, min(2.0, ratio));

      scaledSections.add(_scaleSection(section, ratio));
    }

    return plan.copyWith(sections: scaledSections);
  }

  /// Scale a section's food items by a ratio
  static PlanSection _scaleSection(PlanSection section, double ratio) {
    final scaledFoodItems =
        section.foodItems.map((food) => _scaleFood(food, ratio)).toList();

    List<BeforeSubPhase>? scaledSubPhases;
    if (section.hasSubPhases) {
      scaledSubPhases = section.subPhases!
          .map((sp) => BeforeSubPhase(
                subPhaseType: sp.subPhaseType,
                foodItems: sp.foodItems
                    .map((food) => _scaleFood(food, ratio))
                    .toList(),
                carbsTarget: sp.carbsTarget,
                proteinTarget: sp.proteinTarget,
                fatTarget: sp.fatTarget,
                sodiumTarget: sp.sodiumTarget,
                fluidsTarget: sp.fluidsTarget,
                templateId: sp.templateId,
                templateName: sp.templateName,
              ))
          .toList();
    }

    return section.copyWith(
      foodItems: scaledFoodItems,
      subPhases: scaledSubPhases,
    );
  }

  /// Map section ID to target carbs from MacroTargets
  static double? _getTargetCarbsForSection(
    String sectionId,
    MacroTargets targets,
  ) {
    if (sectionId.startsWith('before')) {
      return targets.preRun.carbsG;
    } else if (sectionId.startsWith('during')) {
      return targets.duringRun.carbTotalG;
    } else if (sectionId.startsWith('after')) {
      return targets.postRun.carbsG;
    }
    return null;
  }

  /// Get total carbs from a section's food items (including sub-phases)
  static double _sectionCarbTotal(PlanSection section) {
    var total = 0.0;

    for (final food in section.foodItems) {
      total += food.nutritionalInfo?.carbs ?? 0;
    }

    if (section.hasSubPhases) {
      for (final sp in section.subPhases!) {
        for (final food in sp.foodItems) {
          total += food.nutritionalInfo?.carbs ?? 0;
        }
      }
    }

    return total;
  }

  /// Scale a food item's quantity and nutritional values
  static FoodItemData _scaleFood(FoodItemData food, double ratio) {
    final quantityNum = _parseQuantity(food.quantity);
    if (quantityNum == null) return food;

    double scaledQuantity = quantityNum * ratio;

    // Round based on indivisibility
    if (food.isIndivisible) {
      scaledQuantity = scaledQuantity.roundToDouble();
      if (scaledQuantity < 1) scaledQuantity = 1;
    } else {
      // Round to nearest 0.5
      scaledQuantity = (scaledQuantity * 2).round() / 2;
      if (scaledQuantity < 0.5) scaledQuantity = 0.5;
    }

    final actualRatio =
        quantityNum > 0 ? scaledQuantity / quantityNum : ratio;
    final scaledInfo =
        _scaleNutritionalInfo(food.nutritionalInfo, actualRatio);

    final quantityStr = scaledQuantity == scaledQuantity.roundToDouble()
        ? scaledQuantity.round().toString()
        : scaledQuantity.toStringAsFixed(1);

    final unitSuffix = _extractUnitSuffix(food.quantity);

    return FoodItemData(
      id: food.id,
      name: food.name,
      quantity: '$quantityStr$unitSuffix',
      imageAddress: food.imageAddress,
      description: food.description,
      timing: food.timing,
      nutritionalInfo: scaledInfo,
      instructions: food.instructions,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      displayOverride: food.displayOverride,
      servingSize: food.servingSize,
      isDrink: food.isDrink,
      isIndivisible: food.isIndivisible,
      templateId: food.templateId,
      scaleMultiplier: actualRatio,
      timingCategory: food.timingCategory,
    );
  }

  /// Extract the unit suffix from a quantity string
  static String _extractUnitSuffix(String quantity) {
    final match = RegExp(r'^[\d.]+(.*)$').firstMatch(quantity.trim());
    return match?.group(1) ?? '';
  }

  /// Parse a numeric quantity from a quantity string
  static double? _parseQuantity(String quantity) {
    final match = RegExp(r'^(\d+\.?\d*)').firstMatch(quantity.trim());
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  /// Scale nutritional info values by a ratio
  static NutritionalInfo? _scaleNutritionalInfo(
    NutritionalInfo? info,
    double ratio,
  ) {
    if (info == null) return null;

    return NutritionalInfo(
      calories:
          info.calories != null ? (info.calories! * ratio).round() : null,
      carbs: info.carbs != null ? (info.carbs! * ratio).round() : null,
      protein:
          info.protein != null ? (info.protein! * ratio).round() : null,
      fat: info.fat != null ? (info.fat! * ratio).round() : null,
      sodium:
          info.sodium != null ? (info.sodium! * ratio).round() : null,
      sugar: info.sugar != null ? (info.sugar! * ratio).round() : null,
      fluids: info.fluids != null ? info.fluids! * ratio : null,
    );
  }
}
