import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/macro_targets.dart' as targets_model;
import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';

/// Separate widget for section subtitles that can be updated independently
/// Takes the plan as a parameter to calculate totals without watching controller
class SectionSubtitleWidget extends StatelessWidget {
  const SectionSubtitleWidget({
    super.key,
    required this.section,
    required this.plan,
    this.macroTargets,
    this.useMetric = false,
  });

  final PlanSection section;
  final NutritionPlan plan;
  final targets_model.MacroTargets? macroTargets;
  final bool useMetric;

  @override
  Widget build(BuildContext context) {
    return _buildBadgeSubtitle();
  }

  /// Build badge-based subtitle with individual ratio pills
  Widget _buildBadgeSubtitle() {
    final totals = _calculateSectionTotals();
    final carbs = totals['carbs']!;
    final protein = totals['protein']!;
    final fluids = totals['fluids']!;
    final sodium = totals['sodium']!;

    List<Widget> badges = [];

    // If no macro targets provided, fall back to plan section targets (legacy)
    if (macroTargets == null) {
      return _buildLegacyBadgeSubtitle(carbs, protein, fluids, sodium);
    }

    final fluidUnit = UnitFormatter.fluidUnitLabel(useMetric: useMetric);

    // Match on section.id (before_run, during_run, after_run) not title for sport-agnostic matching
    if (section.id.contains('before')) {
      final pre = macroTargets!.preRun;
      // M-5 / R-01: whole units at the display edge; the gate path is
      // handled by `hasFluidTarget` below.
      final carbsTarget = pre.carbsG.round();
      final fluidsTarget = (pre.fluidsMl ?? 0).round();

      badges = [
        _buildMacroBadge(
          'Carbs',
          carbs,
          carbsTarget,
          'g',
          _getColorForProgress(carbs, carbsTarget),
        ),
        // Hydration v6: the gate means no fluid target was set at all — show
        // the delivered figure with no ratio rather than "0/0".
        if (pre.hasFluidTarget)
          _buildMacroBadge(
            'Fluids',
            fluids,
            fluidsTarget,
            fluidUnit,
            _getColorForProgress(fluids, fluidsTarget),
          )
        else
          _buildDeliveredBadge('Fluids', fluids, fluidUnit),
        // Sodium v3: Mealvana sets no pre-workout sodium target, so this is a
        // plain delivered figure — no ratio, no in-range colour.
        _buildDeliveredBadge('Sodium', sodium, 'mg'),
      ];
    } else if (section.id.contains('during')) {
      final carbsTarget = macroTargets!.duringRun.carbTotalG.round();
      final fluidsTarget = macroTargets!.duringRun.fluidTotalMl.round();
      final sodiumTarget = macroTargets!.duringRun.sodiumTotalMg.round();

      badges = [
        _buildMacroBadge(
          'Carbs',
          carbs,
          carbsTarget,
          'g',
          _getColorForProgress(carbs, carbsTarget),
        ),
        _buildMacroBadge(
          'Fluids',
          fluids,
          fluidsTarget,
          fluidUnit,
          _getColorForProgress(fluids, fluidsTarget),
        ),
        _buildMacroBadge(
          'Sodium',
          sodium,
          sodiumTarget,
          'mg',
          _getColorForProgress(sodium, sodiumTarget),
        ),
      ];
    } else if (section.id.contains('after')) {
      final carbsTarget = macroTargets!.postRun.carbsG.round();
      final proteinTarget = macroTargets!.postRun.proteinG.round();
      final fluidsTarget = macroTargets!.postRun.fluidsMl.round();

      badges = [
        _buildMacroBadge(
          'Carbs',
          carbs,
          carbsTarget,
          'g',
          _getColorForProgress(carbs, carbsTarget),
        ),
        _buildMacroBadge(
          'Fluids',
          fluids,
          fluidsTarget,
          fluidUnit,
          _getColorForProgress(fluids, fluidsTarget),
        ),
        _buildMacroBadge(
          'Protein',
          protein,
          proteinTarget,
          'g',
          _getColorForProgress(protein, proteinTarget),
        ),
      ];
    } else {
      return Text(
        section.subtitle ?? '',
        style: AppTheme.noteStyle.copyWith(
          color: AppTheme.primary600,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Wrap(spacing: 8.w, runSpacing: 4.h, children: badges);
  }

  /// Build individual macro badge
  Widget _buildMacroBadge(
    String label,
    int current,
    int target,
    String unit,
    Color color,
  ) {
    final ratioWithUnit = '$current/$target$unit';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ratioWithUnit,
            style: AppTheme.textStyle.copyWith(
              color: color,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: AppTheme.noteStyle.copyWith(
              color: color,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// A badge that reports what the food **delivers**, with no target, no
  /// ratio and no in-range colour.
  ///
  /// Used where there is deliberately nothing to compare against: pre-workout
  /// sodium (sodium v3 sets no target) and pre-workout fluid on the gated
  /// path (hydration v6 sets none for a short, mild session).
  Widget _buildDeliveredBadge(String label, int value, String unit) {
    final color = AppTheme.primary900;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value$unit',
            style: AppTheme.textStyle.copyWith(
              color: color,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: AppTheme.noteStyle.copyWith(
              color: color,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Legacy fallback for when MacroTargets is not provided
  Widget _buildLegacyBadgeSubtitle(
    int carbs,
    int protein,
    int fluids,
    int sodium,
  ) {
    List<Widget> badges = [];

    final fluidUnit = UnitFormatter.fluidUnitLabel(useMetric: useMetric);

    // Match on section.id (before_run, during_run, after_run) not title for sport-agnostic matching
    if (section.id.contains('before')) {
      final carbsTarget = plan.sections[0].carbsTarget?.toInt() ?? 0;
      final fluidsTarget = plan.sections[0].fluidsTarget?.toInt() ?? 0;
      final sodiumTarget = plan.sections[0].sodiumTarget?.toInt() ?? 0;

      badges = [
        _buildMacroBadge(
          'Carbs',
          carbs,
          carbsTarget,
          'g',
          _getColorForProgress(carbs, carbsTarget),
        ),
        _buildMacroBadge(
          'Fluids',
          fluids,
          fluidsTarget,
          fluidUnit,
          _getColorForProgress(fluids, fluidsTarget),
        ),
        _buildMacroBadge(
          'Sodium',
          sodium,
          sodiumTarget,
          'mg',
          _getColorForProgress(sodium, sodiumTarget),
        ),
      ];
    } else if (section.id.contains('during')) {
      final carbsTarget = plan.sections[1].carbsTarget?.toInt() ?? 0;
      final fluidsTarget = plan.sections[1].fluidsTarget?.toInt() ?? 0;
      final sodiumTarget = plan.sections[1].sodiumTarget?.toInt() ?? 0;

      badges = [
        _buildMacroBadge(
          'Carbs',
          carbs,
          carbsTarget,
          'g',
          _getColorForProgress(carbs, carbsTarget),
        ),
        _buildMacroBadge(
          'Fluids',
          fluids,
          fluidsTarget,
          fluidUnit,
          _getColorForProgress(fluids, fluidsTarget),
        ),
        _buildMacroBadge(
          'Sodium',
          sodium,
          sodiumTarget,
          'mg',
          _getColorForProgress(sodium, sodiumTarget),
        ),
      ];
    } else if (section.id.contains('after')) {
      final carbsTarget = plan.sections[2].carbsTarget?.toInt() ?? 0;
      final proteinTarget = plan.sections[2].proteinTarget?.toInt() ?? 0;
      final fluidsTarget = plan.sections[2].fluidsTarget?.toInt() ?? 0;

      badges = [
        _buildMacroBadge(
          'Carbs',
          carbs,
          carbsTarget,
          'g',
          _getColorForProgress(carbs, carbsTarget),
        ),
        _buildMacroBadge(
          'Fluids',
          fluids,
          fluidsTarget,
          fluidUnit,
          _getColorForProgress(fluids, fluidsTarget),
        ),
        _buildMacroBadge(
          'Protein',
          protein,
          proteinTarget,
          'g',
          _getColorForProgress(protein, proteinTarget),
        ),
      ];
    } else {
      return Text(
        section.subtitle ?? '',
        style: AppTheme.noteStyle.copyWith(
          color: AppTheme.primary600,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Wrap(spacing: 8.w, runSpacing: 4.h, children: badges);
  }

  /// Get color based on progress towards target
  /// Primary900: Within 10% of target (good)
  /// Highlight400: Over 10% off target (needs attention)
  Color _getColorForProgress(int current, int target) {
    if (target <= 0) return AppTheme.primary900;

    final percentageOff = (current - target).abs() / target;

    if (percentageOff > 0.2) {
      // More than 10% off target
      return AppTheme.highlight400;
    } else {
      // Within 10% of target
      return AppTheme.primary900;
    }
  }

  /// Calculate totals for this section
  Map<String, int> _calculateSectionTotals() {
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalCalories = 0;
    int totalSodium = 0;
    int totalFluids = 0;

    for (final foodItem in section.foodItems) {
      final nutrition = foodItem.nutritionalInfo;
      if (nutrition != null) {
        totalCarbs += nutrition.carbs ?? 0;
        totalProtein += nutrition.protein ?? 0;
        totalCalories += nutrition.calories ?? 0;
        totalSodium += nutrition.sodium ?? 0;
        totalFluids += (nutrition.fluids ?? 0).toInt();
      }
    }

    return {
      'carbs': totalCarbs,
      'protein': totalProtein,
      'calories': totalCalories,
      'sodium': totalSodium,
      'fluids': totalFluids,
    };
  }
}
