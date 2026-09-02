import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_plan.dart';

/// One-line plan header: coverage ("5 of 14 lunch + dinner slots covered")
/// plus the per-day macro contribution when present.
class PlanSummary extends ConsumerWidget {
  const PlanSummary({super.key, required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);

    final coverage = ContentKeys.format(content.getValue(
      ContentKeys.mpCoverageLine,
    ), {
      'covered': plan.coverage.covered,
      'of': plan.coverage.lunchDinnerSlots,
    });

    final perDay = plan.coverage.perDay;
    final macros =
        '≈${perDay.kcal} kcal · ${perDay.carbsG}g carbs · ${perDay.proteinG}g protein / day';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          coverage,
          key: const ValueKey('meal_planning.plan_summary.coverage'),
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(macros, style: AppTextStyles.bodySmall.copyWith(color: secondary)),
      ],
    );
  }
}
