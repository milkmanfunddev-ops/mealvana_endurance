import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/home_service.dart';
import '../../application/meal_plan_controller.dart';
import '../../application/vana_settings_controller.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/meal_plan_status.dart';
import '../../domain/plan_meal.dart';
import '../../domain/ui_action.dart';
import '../widgets/dashed_box.dart';
import '../widgets/plan_list.dart';
import '../widgets/plan_summary.dart';
import '../widgets/staples_card.dart';
import '../widgets/vana_avatar.dart';

/// The Plan tab (05 §4): Vana's day note, this week's plan with swipe
/// actions, the dashed empty state, and the confirm / new-plan actions.
/// Tapping a tile opens the meal's detail page. Offline, the day note hides
/// and the plan renders from the local Drift watch alone.
class PlanTab extends ConsumerWidget {
  const PlanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final planAsync = ref.watch(mealPlanControllerProvider);
    final home = ref.watch(homeControllerProvider()).value;
    final showMacros =
        ref.watch(vanaSettingsControllerProvider).value?.showMacros ?? true;
    final plan = planAsync.value;

    return RefreshIndicator(
      color: AppColors.electrolyte,
      onRefresh: () async {
        await ref.read(homeControllerProvider().notifier).refresh();
        await ref.read(mealPlanControllerProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          // Vana's note for today always has a slot — it carries the entry
          // point into the chat even before there is a plan to talk about.
          _DayNoteCard(
            text: home?.vana.text,
            loading: home == null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            content.getValue(ContentKeys.mpPlanSectionTitle).toUpperCase(),
            key: const ValueKey('meal_planning.plan_section'),
            style: AppTextStyles.overline.copyWith(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.cream
                      : AppColors.blackberry)
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (plan == null || plan.meals.isEmpty)
            _EmptyPlanCard(
              staples: home?.staples != null
                  ? StaplesCard(
                      part: home!.staples!,
                      onTapMeal: (meal) =>
                          context.push('/food/meals/${meal.id}'),
                    )
                  : null,
            )
          else ...[
            PlanSummary(plan: plan),
            const SizedBox(height: AppSpacing.sm),
            PlanList(
              meals: plan.meals,
              showMacros: showMacros,
              onTapMeal: (meal) => context.push(
                '/food/meals/${meal.libraryMealId ?? meal.savedMealId ?? meal.id}',
              ),
              onSwap: (meal) => context.push('/food/swap/${meal.id}'),
              onRemove: (meal) => _removeWithUndo(context, ref, meal),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // "Add meal" / "New meal plan" sit under the plan whether or not
          // one exists — the empty state is a note, not a dead end.
          Row(
            children: [
              Expanded(
                child: KyleSecondaryButton(
                  key: const ValueKey('meal_planning.btn_add_meal'),
                  text: content.getValue(ContentKeys.mpBtnAddMeal),
                  height: 44,
                  onPressed: () => context.push('/food?tab=meals'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: KylePrimaryButton(
                  key: const ValueKey('meal_planning.btn_new_plan'),
                  text: content.getValue(ContentKeys.mpBtnNewPlan),
                  height: 44,
                  onPressed: () =>
                      context.push('/vana?c=new&mode=meal_planning'),
                ),
              ),
            ],
          ),
          if (plan != null &&
              plan.meals.isNotEmpty &&
              plan.status == MealPlanStatus.draft) ...[
            const SizedBox(height: AppSpacing.sm),
            const _ConfirmButton(),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  void _removeWithUndo(BuildContext context, WidgetRef ref, PlanMeal meal) {
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

/// Vana's message for the day — avatar, "Vana · Wed, Sep 2", the precomputed
/// note, and the way in to the general chat. Mirrors the prototype's
/// `VanaMessage` (`.v-vana-msg`): the card is always drawn, with a waiting or
/// no-plan line standing in when there is no note yet.
class _DayNoteCard extends ConsumerWidget {
  const _DayNoteCard({required this.text, this.loading = false});

  final String? text;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = textColor.withValues(alpha: 0.6);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    final body = (text != null && text!.isNotEmpty)
        ? text!
        : content.getValue(
            loading
                ? ContentKeys.mpVanaNoteLoading
                : ContentKeys.mpVanaNoteEmpty,
          );

    return Material(
      key: const ValueKey('meal_planning.day_note'),
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: AppColors.electrolyte.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => context.push('/vana?mode=general'),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VanaAvatar(size: 32, isPulsing: loading),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vana · ${DateFormat('EEE, MMM d').format(DateTime.now())}',
                      style: AppTextStyles.bodySmall.copyWith(color: muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content.getValue(ContentKeys.mpVanaAskAnything),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The no-plan state: one dashed note saying Vana will build the week, with
/// the staples card underneath when the server sent one. The actions live
/// below it in [PlanTab], not inside the box (prototype `.v-dashed`).
class _EmptyPlanCard extends ConsumerWidget {
  const _EmptyPlanCard({required this.staples});

  final Widget? staples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = textColor.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashedBox(
          color: textColor.withValues(alpha: 0.25),
          child: Text(
            content.getValue(ContentKeys.mpEmptyPlanDashed),
            key: const ValueKey('meal_planning.empty_plan_title'),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: muted),
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

/// "Confirm plan · build shopping list" — the primary action on a draft.
class _ConfirmButton extends ConsumerStatefulWidget {
  const _ConfirmButton();

  @override
  ConsumerState<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends ConsumerState<_ConfirmButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);

    return KylePrimaryButton(
      key: const ValueKey('meal_planning.btn_confirm'),
      text: content.getValue(ContentKeys.mpBtnConfirm),
      height: 48,
      isLoading: _busy,
      onPressed: () async {
        final controller = ref.read(mealPlanControllerProvider.notifier);
        setState(() => _busy = true);
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
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }
}
