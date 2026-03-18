import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/nutrition_plan.dart';
import '../../utils/activity_detail_helpers.dart';
import 'macro_range_indicator.dart';

/// Reusable macro summary row for nutrition plan sections
/// Shows actual/target for carbs, fluids/protein (phase-dependent), and sodium
class MacroSummaryRow extends StatelessWidget {
  const MacroSummaryRow({
    super.key,
    required this.foods,
    required this.section,
    required this.category,
    this.useImperial = false,
    this.carbsLow,
    this.carbsHigh,
    this.proteinLow,
    this.proteinHigh,
    this.sodiumLow,
    this.sodiumHigh,
    this.fluidsLow,
    this.fluidsHigh,
  });

  final List<FoodItemData> foods;
  final PlanSection section;
  final String category;
  final bool useImperial;
  final int? carbsLow;
  final int? carbsHigh;
  final int? proteinLow;
  final int? proteinHigh;
  final int? sodiumLow;
  final int? sodiumHigh;
  final int? fluidsLow;
  final int? fluidsHigh;

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
        Expanded(
          child: MacroSummaryItem(
            actual: totalCarbs,
            target: targetCarbs,
            unit: 'g',
            label: 'CARBS',
            low: carbsLow,
            high: carbsHigh,
          ),
        ),
        if (showFluids)
          Expanded(
            child: MacroSummaryItem(
              actual: displayFluidsActual,
              target: displayFluidsTarget,
              unit: fluidsUnit,
              label: 'FLUIDS',
              low: useImperial && fluidsLow != null
                  ? (fluidsLow! * 0.033814).round()
                  : fluidsLow,
              high: useImperial && fluidsHigh != null
                  ? (fluidsHigh! * 0.033814).round()
                  : fluidsHigh,
            ),
          )
        else
          Expanded(
            child: MacroSummaryItem(
              actual: totalProtein,
              target: targetProtein,
              unit: 'g',
              label: 'PROTEIN',
              low: proteinLow,
              high: proteinHigh,
            ),
          ),
        Expanded(
          child: MacroSummaryItem(
            actual: totalSodium,
            target: targetSodium,
            unit: 'mg',
            label: 'SODIUM',
            low: sodiumLow,
            high: sodiumHigh,
          ),
        ),
      ],
    );
  }
}

/// Individual macro summary item with prominent value, label, and visual range bar
class MacroSummaryItem extends StatelessWidget {
  const MacroSummaryItem({
    super.key,
    required this.actual,
    required this.target,
    required this.unit,
    required this.label,
    this.low,
    this.high,
  });

  final int actual;
  final int target;
  final String unit;
  final String label;
  final int? low;
  final int? high;

  bool get _hasRange => low != null && high != null && (low! > 0 || high! > 0);

  @override
  Widget build(BuildContext context) {
    final actualColor = ActivityDetailHelpers.getMacroRangeColor(
      context,
      actual,
      target,
      low: low,
      high: high,
    );
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (!_hasRange) {
      // No range: show compact "actual/target unit" format
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
                  text: '/$target$unit',
                  style: AppTextStyles.dataNumber.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
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
              color: mutedColor,
              fontSize: 10,
            ),
          ),
        ],
      );
    }

    // Range mode: prominent value + label + range bar + min/max
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Large value with unit
          Text(
            '$actual$unit',
            style: AppTextStyles.dataNumber.copyWith(
              color: actualColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: mutedColor,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          // Range bar
          MacroRangeIndicator(
            value: actual,
            min: low!,
            max: high!,
            color: actualColor,
          ),
          const SizedBox(height: 2),
          // Min / Max labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$low',
                style: AppTextStyles.smallLabel.copyWith(
                  color: mutedColor,
                  fontSize: 9,
                ),
              ),
              Text(
                '$high',
                style: AppTextStyles.smallLabel.copyWith(
                  color: mutedColor,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
