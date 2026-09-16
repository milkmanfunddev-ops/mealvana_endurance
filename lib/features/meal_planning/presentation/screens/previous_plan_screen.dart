import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/plan_meal_photos.dart';
import '../../application/previous_plans.dart';
import '../../application/vana_settings_controller.dart';
import '../../domain/meal_plan.dart';
import '../widgets/plan_summary.dart';
import '../widgets/plan_tile.dart';
import '../widgets/vana_round_button.dart';

/// An earlier plan, read-only (`/food/plans/:id`): the plan's week and meal
/// count as the header, then the same rows the Plan tab draws, without the
/// swipes, the per-row ⋮ or a Confirm button. The back button is the way
/// back to this week. Tapping a row still opens the meal's page.
class PreviousPlanScreen extends ConsumerWidget {
  const PreviousPlanScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final planAsync = ref.watch(planByIdProvider(planId));

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  VanaRoundButton.back(
                    key: const ValueKey('meal_planning.previous_plan_back'),
                    context: context,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: switch (planAsync.value) {
                      final MealPlan plan => PlanSummary(plan: plan),
                      null => Text(
                        content.getValue(ContentKeys.mpPlanPrevious),
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: textColor,
                          fontSize: 20,
                        ),
                      ),
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: planAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _Note(
                  content.getValue(ContentKeys.mpPreviousPlansFailed),
                  key: const ValueKey('meal_planning.previous_plan_failed'),
                ),
                data: (plan) => plan == null
                    ? _Note(
                        content.getValue(ContentKeys.mpPreviousPlanMissing),
                        key: const ValueKey(
                          'meal_planning.previous_plan_missing',
                        ),
                      )
                    : _ReadOnlyRows(plan: plan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-line note in the body — the plan is gone, or the read failed.
class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: textColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// The plan's rows as [PlanTile]s with no actions wired, under the
/// "view only" line.
class _ReadOnlyRows extends ConsumerWidget {
  const _ReadOnlyRows({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final showMacros =
        ref.watch(vanaSettingsControllerProvider).value?.showMacros ?? true;
    final slots = ref.planPhotoSlots(plan.meals);

    return ListView(
      key: const ValueKey('meal_planning.previous_plan_rows'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          content.getValue(ContentKeys.mpPreviousPlanReadOnly),
          key: const ValueKey('meal_planning.previous_plan_read_only'),
          style: AppTextStyles.bodySmall.copyWith(
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (i, meal) in plan.meals.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          PlanTile(
            key: ValueKey('meal_planning.previous_plan_tile_${meal.id}'),
            meal: meal,
            slot: slots[meal.id],
            showMacros: showMacros,
            onTap: () => context.push(
              '/food/meals/${meal.libraryMealId ?? meal.savedMealId ?? meal.id}',
            ),
          ),
        ],
      ],
    );
  }
}
