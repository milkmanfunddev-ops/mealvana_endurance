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
import '../../application/vana_ambient_conversation_controller.dart';
import '../../application/vana_settings_controller.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/meal_plan_status.dart';
import '../../domain/plan_meal.dart';
import '../../domain/ui_action.dart';
import '../widgets/dashed_box.dart';
import '../widgets/plan_list.dart';
import '../widgets/plan_overflow_menu.dart';
import '../widgets/plan_summary.dart';
import '../widgets/previous_plans_sheet.dart';
import '../../../../shared/widgets/kyle_design/icons/vana_avatar.dart';
import 'food_screen.dart';

/// `intent=new_plan`: the athlete chose a fresh plan, so the opener builds
/// one and never asks about the plan on this tab. Both ways in — the button
/// and the plan's ⋮ — send exactly this.
const _newPlanRoute = '/vana?c=new&mode=meal_planning&intent=new_plan';

/// The Plan tab (05 §4): Vana's day note, this week's plan with swipe
/// actions, the dashed empty state, and the confirm / new-plan actions. The
/// plan's ⋮ also opens the earlier plans, each viewable read-only at
/// `/food/plans/:id`.
/// Tapping a tile opens the meal's detail page. Offline, the day note hides
/// and the plan renders from the local Drift watch alone.
class PlanTab extends ConsumerWidget {
  const PlanTab({super.key, this.onAddMeal, this.onShowShopping});

  /// "Add meal": the Food screen switches to its Meals segment. Without one,
  /// the Food tab is opened on Meals ([goToFoodTab]).
  final VoidCallback? onAddMeal;

  /// Where Rebuild shopping list lands once the server has answered. Without
  /// one, the Food tab is opened on Shopping ([goToFoodTab]).
  final VoidCallback? onShowShopping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final planAsync = ref.watch(mealPlanControllerProvider);
    final home = ref.watch(homeControllerProvider()).value;
    final showMacros =
        ref.watch(vanaSettingsControllerProvider).value?.showMacros ?? true;
    final plan = planAsync.value;
    // No plan to show and a read on the wire: loading, never the dashed
    // "No plan yet" over a plan confirmed elsewhere (testing-wave 19-004).
    final loading = plan == null && planAsync.isLoading;

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
          _DayNoteCard(text: home?.vana.text, loading: home == null),
          const SizedBox(height: AppSpacing.md),
          if (loading)
            const _LoadingPlanCard()
          else if (plan == null || plan.meals.isEmpty)
            const _EmptyPlanCard()
          else ...[
            // The plan's header: its week and meal count, the ⋮ on the right.
            // (The "This week's plan" overline above it went on 2026-09-16.)
            Row(
              children: [
                Expanded(child: PlanSummary(plan: plan)),
                PlanOverflowMenu(
                  onStartNew: () => context.push(_newPlanRoute),
                  onPrevious: () => showPreviousPlansSheet(
                    context: context,
                    onOpen: (id) => context.push('/food/plans/$id'),
                  ),
                  // The confirmed plan's list can be deleted; this is the
                  // way back (ticket 96, Lee 09-25). A draft's list is not
                  // the Shopping tab's list until Confirm builds it.
                  onRebuildList: plan.status == MealPlanStatus.confirmed
                      ? () => _rebuildList(context, ref)
                      : null,
                  onDelete: () => _deletePlanWithUndo(context, ref),
                ),
              ],
            ),
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
                  onPressed:
                      onAddMeal ?? () => goToFoodTab(context, FoodTab.meals),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: KylePrimaryButton(
                  key: const ValueKey('meal_planning.btn_new_plan'),
                  text: content.getValue(ContentKeys.mpBtnNewPlan),
                  height: 44,
                  // A new plan waits for the read: started over a plan
                  // still loading, it would double the week (19-004).
                  onPressed: loading ? null : () => context.push(_newPlanRoute),
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

  /// Rebuild shopping list: the server remakes the plan's one list from its
  /// meals, then the athlete lands on it. Nothing moves until the server has
  /// answered; offline or refused, a snackbar says so and the tab stays.
  Future<void> _rebuildList(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    try {
      await ref.read(mealPlanControllerProvider.notifier).rebuildShoppingList();
      if (!context.mounted) return;
      final show = onShowShopping;
      if (show != null) {
        show();
      } else {
        goToFoodTab(context, FoodTab.shopping);
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
  }

  /// Delete the plan by hand: ask first (it takes the week's meals and the
  /// shopping list with it), then offer Undo for as long as the snackbar is
  /// up. The receipt the server answers with is what Undo sends back.
  Future<void> _deletePlanWithUndo(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(mealPlanControllerProvider.notifier);
    final content = ref.read(contentServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('meal_planning.plan_delete_confirm'),
        backgroundColor: Theme.of(dialogContext).scaffoldBackgroundColor,
        title: Text(content.getValue(ContentKeys.mpPlanDeleteTitle)),
        content: Text(content.getValue(ContentKeys.mpPlanDeleteBody)),
        actions: [
          TextButton(
            key: const ValueKey('meal_planning.plan_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(content.getValue(ContentKeys.mpPlanDeleteCancel)),
          ),
          TextButton(
            key: const ValueKey('meal_planning.plan_delete_go'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              content.getValue(ContentKeys.mpPlanDeleteConfirm),
              style: const TextStyle(color: AppColors.dragonfruitLight),
            ),
          ),
        ],
      ),
    );
    // Dismissed by tapping outside, or kept: nothing is sent.
    if (confirmed != true || !context.mounted) return;

    try {
      final receipt = await controller.deletePlan();
      if (!context.mounted) return;
      MealvanaSnackbar.showInfo(
        context,
        content.getValue(ContentKeys.mpPlanDeleted),
        duration: MealvanaSnackbar.longDuration,
        // A receipt with no undo (the server could not put it back) gets no
        // Undo button rather than one that fails on tap.
        actionLabel: receipt?.undo == null
            ? null
            : content.getValue(ContentKeys.mpUndo),
        onAction: receipt?.undo == null
            ? null
            : () async {
                try {
                  await controller.undoDeletePlan(receipt!);
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
        // The day's ambient conversation, the one the launcher opens
        // (mp-275 clause 1), never a conversation of its own.
        onTap: () async {
          final router = GoRouter.of(context);
          String? id;
          try {
            id = await ref
                .read(vanaAmbientConversationProvider.notifier)
                .openToday();
          } catch (_) {
            id = null;
          }
          router.push(vanaAmbientChatLocation(id));
        },
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

/// The first read is on the wire: the dashed slot holds a spinner where the
/// plan will be, so the tab never says "No plan yet" over a plan confirmed
/// elsewhere (testing-wave 19-004).
class _LoadingPlanCard extends StatelessWidget {
  const _LoadingPlanCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return DashedBox(
      key: const ValueKey('meal_planning.plan_loading'),
      color: textColor.withValues(alpha: 0.25),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.electrolyte,
          ),
        ),
      ),
    );
  }
}

/// The no-plan state: one dashed note saying Vana will build the week. The
/// actions live below it in [PlanTab], not inside the box (prototype
/// `.v-dashed`). The staples card that used to sit underneath was dropped
/// from the Food tab on 2026-09-07 (Lee) — it remains a chat part.
class _EmptyPlanCard extends ConsumerWidget {
  const _EmptyPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = textColor.withValues(alpha: 0.6);

    return DashedBox(
      color: textColor.withValues(alpha: 0.25),
      child: Text(
        content.getValue(ContentKeys.mpEmptyPlanDashed),
        key: const ValueKey('meal_planning.empty_plan_title'),
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(color: muted),
      ),
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
