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
import '../../domain/meal_plan_status.dart';
import '../../domain/meal_plan_summary.dart';
import 'plan_conversation_title.dart';
import 'plan_summary.dart';

/// The plan ⋮'s "Previous plans": a sheet of the athlete's earlier plans,
/// newest week first, the week's confirmed plan leading with a Confirmed
/// tag (17-004), each its name (or its week) and a meal count. Tapping one
/// hands its id to [onOpen], which pushes the plan's view, where it is
/// edited, renamed, deleted or used again (mp-675). The sheet stays under
/// that view, so Back lands on it where it was scrolled (17-007); it closes
/// itself when this week's plan changes underneath it (a Use again
/// confirmed), since the athlete's business is then the Plan tab.
Future<void> showPreviousPlansSheet({
  required BuildContext context,
  required ValueChanged<String> onOpen,
}) => showAdaptiveModal<void>(
  context: context,
  builder: (_) => PreviousPlansSheet(onOpen: onOpen),
);

/// The sheet's body — the same rows as the Shopping tab's earlier lists
/// (`ShoppingPreviousLists`), so history looks the same wherever it is.
class PreviousPlansSheet extends ConsumerWidget {
  const PreviousPlansSheet({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(mealPlanControllerProvider.select((s) => s.value?.id), (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;
      // The plan's view pops itself right after the confirm; close the
      // sheet once it is the route on top again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
      });
    });
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

    // A named plan leads with its name and keeps its week on the second
    // line; an unnamed one is its week, as before.
    (String, String) lines(MealPlanSummary plan) {
      final week = PlanSummary.weekLabel(plan.weekStart, periodDays);
      final meals = mealsLabel(plan.mealCount);
      final name = plan.name;
      return name == null ? (week, meals) : (name, '$week · $meals');
    }

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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  lines(plans[i]).$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (plans[i].status ==
                                  MealPlanStatus.confirmed) ...[
                                const SizedBox(width: AppSpacing.xs),
                                _StateTag(
                                  key: ValueKey(
                                    'meal_planning.previous_plan_confirmed_'
                                    '${plans[i].id}',
                                  ),
                                  text: planStateLabel(
                                    content,
                                    MealPlanStatus.confirmed,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lines(plans[i]).$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

/// The "Confirmed" tag on the week's confirmed plan: the plan card's badge
/// (`PlanCard`) at row size.
class _StateTag extends StatelessWidget {
  const _StateTag({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.electrolyte,
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      child: Text(
        text,
        style: AppTextStyles.smallLabel.copyWith(
          color: AppColors.blackberry,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
