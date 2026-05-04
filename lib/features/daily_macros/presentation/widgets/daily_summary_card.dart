import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/daily_macro_targets.dart';
import 'energy_source_breakdown.dart';
import 'macro_breakdown_row.dart';

/// Card showing daily macro summary:
/// Row 1: "1,130 cal" (left) | "Daily Total" (right)
/// Row 2: colored macro breakdown (carbs/protein/fat with dot indicators)
class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({
    super.key,
    required this.macros,
  });

  final DailyMacroTargets macros;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return BaseCard(
      child: Column(
        children: [
          // Compact header row: calories left, "Daily Total" right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${NumberFormat('#,###').format(macros.totalCalories.round())} cal',
                style: AppTextStyles.pageTitle.copyWith(
                  color: textColor,
                  fontSize: 28,
                ),
              ),
              Text(
                'Daily Total',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Macro breakdown with colored dots
          MacroBreakdownRow(
            carbG: macros.carbG,
            protG: macros.protG,
            fatG: macros.fatG,
            textColor: textColor,
          ),

          // Energy breakdown (RMR / NEAT / Workout) with Garmin attribution
          // for any line that came from Garmin Connect data.
          const SizedBox(height: AppSpacing.lg),
          EnergySourceBreakdown(macros: macros),
        ],
      ),
    );
  }
}
