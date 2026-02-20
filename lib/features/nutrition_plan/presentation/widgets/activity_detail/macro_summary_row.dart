import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/nutrition_plan.dart';
import '../../utils/activity_detail_helpers.dart';

/// Reusable macro summary row for nutrition plan sections
/// Shows actual/target for carbs, fluids/protein (phase-dependent), and sodium
class MacroSummaryRow extends StatelessWidget {
  const MacroSummaryRow({
    super.key,
    required this.foods,
    required this.section,
    required this.category,
    this.useImperial = false,
  });

  final List<FoodItemData> foods;
  final PlanSection section;
  final String category;
  final bool useImperial;

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalSodium = 0;
    double totalFluids = 0;

    for (final food in foods) {
      if (food.nutritionalInfo != null) {
        totalCarbs += food.nutritionalInfo!.carbs ?? 0;
        totalProtein += food.nutritionalInfo!.protein ?? 0;
        totalSodium += food.nutritionalInfo!.sodium ?? 0;
        totalFluids += food.nutritionalInfo!.fluids ?? 0;
      }
    }

    // Get targets
    int targetCarbs = section.carbsTarget?.round() ?? totalCarbs;
    int targetProtein = section.proteinTarget?.round() ?? totalProtein;
    int targetSodium = section.sodiumTarget?.round() ?? totalSodium;
    int targetFluids = section.fluidsTarget?.round() ?? totalFluids.round();

    int displayFluidsActual = totalFluids.round();
    int displayFluidsTarget = targetFluids;
    String fluidsUnit = 'mL';

    if (useImperial) {
      displayFluidsActual = (totalFluids * 0.033814).round();
      displayFluidsTarget = (targetFluids * 0.033814).round();
      fluidsUnit = 'oz';
    }

    final categoryLower = category.toLowerCase();
    final isDuringSection = categoryLower.contains('during');
    final isBeforeSection = categoryLower.contains('before');
    final showFluids = isBeforeSection || isDuringSection;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        MacroSummaryItem(
          actual: totalCarbs,
          target: targetCarbs,
          unit: 'g',
          label: 'CARBS',
        ),
        if (showFluids)
          MacroSummaryItem(
            actual: displayFluidsActual,
            target: displayFluidsTarget,
            unit: fluidsUnit,
            label: 'FLUIDS',
          )
        else
          MacroSummaryItem(
            actual: totalProtein,
            target: targetProtein,
            unit: 'g',
            label: 'PROTEIN',
          ),
        MacroSummaryItem(
          actual: totalSodium,
          target: targetSodium,
          unit: 'mg',
          label: 'SODIUM',
        ),
      ],
    );
  }
}

/// Individual macro summary item showing actual/target values
class MacroSummaryItem extends StatelessWidget {
  const MacroSummaryItem({
    super.key,
    required this.actual,
    required this.target,
    required this.unit,
    required this.label,
  });

  final int actual;
  final int target;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final actualColor = ActivityDetailHelpers.getMacroDeviationColor(
      context,
      actual,
      target,
    );
    final targetColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$actual',
                style: AppTextStyles.dataNumber.copyWith(
                  color: actualColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '/',
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '$target',
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: unit,
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
