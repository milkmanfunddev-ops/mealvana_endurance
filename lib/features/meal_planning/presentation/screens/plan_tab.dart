import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../application/home_service.dart';
import '../../application/meal_plan_controller.dart';
import '../../application/vana_settings_controller.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/meal_plan_status.dart';
import '../../domain/plan_meal.dart';
import '../../domain/ui_action.dart';
import '../widgets/plan_list.dart';
import '../widgets/plan_summary.dart';
import '../widgets/staples_card.dart';
import '../widgets/tile_sheet.dart';

/// The Plan tab (05 §4): Vana's day note, this week's plan with swipe
/// actions and the tile sheet, the dashed empty state, and the confirm /
/// new-plan actions. Offline, the day note hides and the plan renders from
/// the local Drift watch alone.
class PlanTab extends ConsumerWidget {
  const PlanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final planAsync = ref.watch(mealPlanControllerProvider);
    final home = ref.watch(homeControllerProvider()).value;
    final showMacros =
        ref.watch(vanaSettingsControllerProvider).value?.showMacros ?? false;
    final plan = planAsync.value;

    return RefreshIndicator(
      color: AppColors.electrolyte,
      onRefresh: () async {
        await ref.read(homeControllerProvider().notifier).refresh();
        await ref.read(mealPlanControllerProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (home?.vana.text != null && home!.vana.text!.isNotEmpty)
            _DayNoteCard(text: home.vana.text!),
          const SizedBox(height: AppSpacing.md),
          Text(
            content.getValue(ContentKeys.mpPlanSectionTitle),
            key: const ValueKey('meal_planning.plan_section'),
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          const _TodayTargetLine(),
          const SizedBox(height: AppSpacing.sm),
          if (plan == null || plan.meals.isEmpty)
            _EmptyPlanCard(
              staples:
                  home?.staples != null
                  ? StaplesCard(
                      part: home!.staples!,
                      onTapMeal: (meal) =>
                          context.push('/food/meals/${meal.id}'),
                    )
                  : null,
              onAddMeal: () => context.push('/food?tab=meals'),
              onNewPlan: () => context.push('/vana?c=new&mode=meal_planning'),
            )
          else ...[
            PlanSummary(plan: plan),
            const SizedBox(height: AppSpacing.sm),
            PlanList(
              meals: plan.meals,
              showMacros: showMacros,
              onTapMeal: (meal) => _openTileSheet(context, ref, meal),
              onSwap: (meal) => context.push('/food/swap/${meal.id}'),
              onRemove: (meal) => _removeWithUndo(context, ref, meal),
            ),
            if (plan.status == MealPlanStatus.draft) ...[
              const SizedBox(height: AppSpacing.md),
              const _ConfirmButton(),
            ],
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _openTileSheet(
    BuildContext context,
    WidgetRef ref,
    PlanMeal meal,
  ) {
    final controller = ref.read(mealPlanControllerProvider.notifier);
    return showTileSheet(
      context: context,
      ref: ref,
      meal: meal,
      onServings: (servings) => controller.setServings(meal.id, servings),
      onSwap: () => context.push('/food/swap/${meal.id}'),
      onRemove: () => _removeWithUndo(context, ref, meal),
    );
  }

  void _removeWithUndo(
    BuildContext context,
    WidgetRef ref,
    PlanMeal meal,
  ) {
    final controller = ref.read(mealPlanControllerProvider.notifier);
    final content = ref.read(contentServiceProvider);
    controller.removeMeal(meal.id);
    MealvanaSnackbar.showInfo(
      context,
      content.getValue(ContentKeys.mpRemoveUndone),
      duration: MealvanaSnackbar.longDuration,
      actionLabel: content.getValue(ContentKeys.mpUndo),
      // Re-pick the same meal at the same serving count on undo.
      onAction: () async {
        try {
          await controller.pickMeals([
            MealPick(
              source: meal.source,
              id: meal.libraryMealId ?? meal.savedMealId ?? '',
            ),
          ], servings: meal.servings);
        } on Exception {
          if (context.mounted) {
            MealvanaSnackbar.showError(
              context,
              content.getValue(ContentKeys.mpServerError),
            );
          }
        }
      },
    );
  }
}

/// Vana's precomputed note for today; tap opens the general chat.
class _DayNoteCard extends StatelessWidget {
  const _DayNoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return Material(
      key: const ValueKey('meal_planning.day_note'),
      color: surface,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/vana?mode=general'),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FaIcon(FontAwesomeIcons.wandMagicSparkles, color: accent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayTargetLine extends ConsumerWidget {
  const _TodayTargetLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.65);
    final targets =
        ref.watch(dailyMacrosControllerProvider).value?.dailyMacros;
    if (targets == null) return const SizedBox.shrink();

    return Text(
      ContentKeys.format(content.getValue(ContentKeys.mpTodayTargetLine), {
        'carbs': targets.carbG.round(),
        'protein': targets.protG.round(),
        'kcal': (targets.tdee + targets.sessionKcal).round(),
      }),
      key: const ValueKey('meal_planning.today_target'),
      style: AppTextStyles.bodySmall.copyWith(color: secondary),
    );
  }
}

class _EmptyPlanCard extends ConsumerWidget {
  const _EmptyPlanCard({
    required this.staples,
    required this.onAddMeal,
    required this.onNewPlan,
  });

  final Widget? staples;
  final VoidCallback onAddMeal;
  final VoidCallback onNewPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            color: secondary.withValues(alpha: 0.6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  content.getValue(ContentKeys.mpEmptyPlanTitle),
                  key: const ValueKey('meal_planning.empty_plan_title'),
                  style: AppTextStyles.sectionTitle.copyWith(color: textColor),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  content.getValue(ContentKeys.mpEmptyPlanBody),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('meal_planning.btn_add_meal'),
                      onPressed: onAddMeal,
                      icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                      label: Text(content.getValue(ContentKeys.mpBtnAddMeal)),
                    ),
                    TextButton.icon(
                      key: const ValueKey('meal_planning.btn_new_plan'),
                      onPressed: onNewPlan,
                      icon: const FaIcon(
                        FontAwesomeIcons.wandMagicSparkles,
                        size: 14,
                      ),
                      label: Text(content.getValue(ContentKeys.mpBtnNewPlan)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (staples != null) ...[
          const SizedBox(height: AppSpacing.sm),
          staples!,
        ],
      ],
    );
  }
}

class _ConfirmButton extends ConsumerWidget {
  const _ConfirmButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        key: const ValueKey('meal_planning.btn_confirm'),
        onPressed: () async {
          final controller = ref.read(mealPlanControllerProvider.notifier);
          try {
            await controller.confirmPlan();
            if (context.mounted) {
              MealvanaSnackbar.showSuccess(
                context,
                content.getValue(ContentKeys.mpConfirmedToast),
              );
            }
          } on NeedsConnectionException {
            if (context.mounted) {
              MealvanaSnackbar.showWarning(
                context,
                content.getValue(ContentKeys.mpNeedsConnection),
              );
            }
          } on Exception {
            if (context.mounted) {
              MealvanaSnackbar.showError(
                context,
                content.getValue(ContentKeys.mpServerError),
              );
            }
          }
        },
        style: TextButton.styleFrom(
          backgroundColor: accent.withValues(alpha: 0.16),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        ),
        child: Text(
          content.getValue(ContentKeys.mpBtnConfirm),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.blackberry,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dash = 6.0;
    const gap = 4.0;
    final radius = Radius.circular(AppSpacing.sm);

    // Rounded-rect path walked in dashes.
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, radius),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, next),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
