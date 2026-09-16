import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_plan.dart';

/// The line above the plan list: the week it covers and how many meals are in
/// it — "Aug 30 – Sep 5 · 2 meals", the count in orange. Mirrors the
/// prototype's `PlanSummary`.
class PlanSummary extends ConsumerWidget {
  const PlanSummary({super.key, required this.plan});

  final MealPlan plan;

  /// "Aug 30 – Sep 5" for the [periodDays] days starting at [weekStart]
  /// (the athlete's plan period, mp-269).
  static String weekLabel(String weekStart, [int periodDays = 7]) {
    final start = DateTime.tryParse(weekStart);
    if (start == null) return weekStart;
    final fmt = DateFormat('MMM d');
    final end = DateTime(start.year, start.month, start.day + periodDays - 1);
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final count = plan.meals.length;
    final meals = count == 1
        ? content.getValue(ContentKeys.mpPlanWeekMealOne)
        : ContentKeys.format(content.getValue(ContentKeys.mpPlanWeekMeals), {
            'n': count,
          });

    return RichText(
      key: const ValueKey('meal_planning.plan_summary.coverage'),
      text: TextSpan(
        style: AppTextStyles.sectionTitle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        children: [
          TextSpan(
            text: weekLabel(plan.weekStart, plan.coverage.periodDays),
          ),
          TextSpan(
            text: ' · $meals',
            style: const TextStyle(color: AppColors.orange),
          ),
        ],
      ),
    );
  }
}
