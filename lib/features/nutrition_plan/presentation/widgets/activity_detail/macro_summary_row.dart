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
    this.carbsOverridden = false,
    this.proteinOverridden = false,
    this.sodiumOverridden = false,
    this.fluidsOverridden = false,
    this.carbsOverrideLabel,
    this.proteinOverrideLabel,
    this.sodiumOverrideLabel,
    this.fluidsOverrideLabel,
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
  final bool carbsOverridden;
  final bool proteinOverridden;
  final bool sodiumOverridden;
  final bool fluidsOverridden;

  /// Optional display labels for overrides (e.g., "120g/hr" for during carbs).
  final String? carbsOverrideLabel;
  final String? proteinOverrideLabel;
  final String? sodiumOverrideLabel;
  final String? fluidsOverrideLabel;

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
            isOverridden: carbsOverridden,
            overrideLabel: carbsOverrideLabel,
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
              isOverridden: fluidsOverridden,
              overrideLabel: fluidsOverrideLabel,
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
              isOverridden: proteinOverridden,
              overrideLabel: proteinOverrideLabel,
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
            isOverridden: sodiumOverridden,
            overrideLabel: sodiumOverrideLabel,
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
    this.isOverridden = false,
    this.overrideLabel,
  });

  final int actual;
  final int target;
  final String unit;
  final String label;
  final int? low;
  final int? high;
  final bool isOverridden;

  /// Display label for the override value (e.g., "120g/hr").
  /// When null, falls back to showing "$target$unit".
  final String? overrideLabel;

  bool get _hasRange => low != null && high != null && (low! > 0 || high! > 0);

  /// Whether the target exceeds the recommended range upper bound.
  bool get _exceedsRange => _hasRange && target > high!;

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
      // No range provided. When target is 0 (spec says "no recommendation"),
      // showing "actual/0 unit" reads as broken data — render just `actual unit`.
      // Otherwise keep the compact "actual/target unit" format.
      final showFlat = target == 0;
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
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
                      text: showFlat ? unit : '/$target$unit',
                      style: AppTextStyles.dataNumber.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOverridden) _buildOverrideIcon(context),
            ],
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
          // Large value with unit + override icon
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$actual$unit',
                style: AppTextStyles.dataNumber.copyWith(
                  color: actualColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isOverridden) _buildOverrideIcon(context),
            ],
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

  Widget _buildOverrideIcon(BuildContext context) {
    final iconColor = _exceedsRange
        ? Colors.amber.shade700
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => _showOverrideSheet(context),
      child: Padding(
        padding: const EdgeInsets.only(left: 2, top: 1),
        child: Icon(Icons.info_outline_rounded, size: 14, color: iconColor),
      ),
    );
  }

  void _showOverrideSheet(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Custom ${label[0]}${label.substring(1).toLowerCase()} Target',
              style: AppTextStyles.sectionTitle.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (overrideLabel != null) ...[
              Text(
                'Your override: $overrideLabel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Calculated target: $target$unit for this activity',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ] else
              Text(
                'Your target: $target$unit',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
            if (_hasRange) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Recommended range: $low\u2013$high$unit',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ],
            if (_exceedsRange) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This target exceeds the recommended range. '
                        'High intake may cause GI distress \u2014 consider '
                        'training your gut if targeting above $high$unit.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'This target was set in your nutrition settings and overrides '
              'the algorithm\u2019s default calculation.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
