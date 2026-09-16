import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_plan_controller.dart';
import '../../application/previous_plans.dart';
import '../../domain/meal_plan_summary.dart';
import 'plan_summary.dart';

/// The plan ⋮'s "Previous plans": a sheet of the athlete's earlier plans,
/// newest first, each a week label and a meal count. Tapping one closes the
/// sheet and hands its id to [onOpen], which pushes the read-only view.
Future<void> showPreviousPlansSheet({
  required BuildContext context,
  required ValueChanged<String> onOpen,
}) => showAdaptiveModal<void>(
  context: context,
  builder: (sheetContext) => PreviousPlansSheet(
    onOpen: (id) {
      Navigator.of(sheetContext).pop();
      onOpen(id);
    },
  ),
);

/// The sheet's body — the same rows as the Shopping tab's earlier lists
/// (`ShoppingPreviousLists`), so history looks the same wherever it is.
class PreviousPlansSheet extends ConsumerWidget {
  const PreviousPlansSheet({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final plans = ref.watch(previousPlansProvider);
    // The period the athlete plans over — the summary row carries no
    // coverage, so the label's length comes from the current setting.
    final periodDays = ref.watch(planPeriodProvider).value?.days ?? 7;

    return SafeArea(
      key: const ValueKey('meal_planning.previous_plans_sheet'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.getValue(ContentKeys.mpPlanPrevious),
              style: AppTextStyles.sectionTitle.copyWith(
                color: textColor,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            plans.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(
                content.getValue(ContentKeys.mpPreviousPlansFailed),
                key: const ValueKey('meal_planning.previous_plans_failed'),
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
              data: (list) => list.isEmpty
                  ? Text(
                      content.getValue(ContentKeys.mpPreviousPlansEmpty),
                      key: const ValueKey('meal_planning.previous_plans_empty'),
                      style: AppTextStyles.bodySmall.copyWith(color: secondary),
                    )
                  : Flexible(
                      child: _PlanRows(
                        plans: list,
                        periodDays: periodDays,
                        onOpen: onOpen,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _PlanRows extends ConsumerWidget {
  const _PlanRows({
    required this.plans,
    required this.periodDays,
    required this.onOpen,
  });

  final List<MealPlanSummary> plans;
  final int periodDays;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final hairline = textColor.withValues(alpha: 0.1);

    String mealsLabel(int n) => n == 1
        ? content.getValue(ContentKeys.mpPlanWeekMealOne)
        : ContentKeys.format(content.getValue(ContentKeys.mpPlanWeekMeals), {
            'n': n,
          });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (var i = 0; i < plans.length; i++)
            InkWell(
              key: ValueKey('meal_planning.previous_plan_${plans[i].id}'),
              onTap: () => onOpen(plans[i].id),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  border: i == plans.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            PlanSummary.weekLabel(
                              plans[i].weekStart,
                              periodDays,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mealsLabel(plans[i].mealCount),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: secondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
