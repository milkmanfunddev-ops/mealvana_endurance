import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/plan_meal_photos.dart';
import '../../application/previous_plans.dart';
import '../../application/vana_settings_controller.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/meal_plan.dart';
import '../widgets/overflow_menu.dart';
import '../widgets/plan_summary.dart';
import '../widgets/plan_tile.dart';
import '../widgets/stepper.dart';
import '../widgets/vana_round_button.dart';

/// An earlier plan (`/food/plans/:id`): its name, if the athlete gave it
/// one, over the week and meal count, then the same rows the Plan tab draws.
/// Plans are a list (mp-675): each row's servings step and its ⋮ removes
/// it; the header's ⋮ renames the plan, uses it again as this week's new
/// draft, or deletes it. A draft (the copy Use again made) has a Confirm
/// that makes it this week's plan. The back button is the way back.
class PreviousPlanScreen extends ConsumerWidget {
  const PreviousPlanScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final planAsync = ref.watch(earlierPlanProvider(planId));
    final plan = planAsync.value;

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
                    child: switch (plan) {
                      final MealPlan plan => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (plan.name case final String name)
                            Text(
                              name,
                              key: const ValueKey(
                                'meal_planning.previous_plan_name',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: textColor,
                                fontSize: 20,
                              ),
                            ),
                          PlanSummary(plan: plan),
                        ],
                      ),
                      null => Text(
                        content.getValue(ContentKeys.mpPlanPrevious),
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: textColor,
                          fontSize: 20,
                        ),
                      ),
                    },
                  ),
                  if (plan != null)
                    OverflowMenu(
                      key: const ValueKey('meal_planning.previous_plan_more'),
                      tooltip: content.getValue(ContentKeys.mpPlanMore),
                      items: [
                        OverflowMenuItem(
                          key: const ValueKey(
                            'meal_planning.previous_plan_rename',
                          ),
                          label: content.getValue(
                            ContentKeys.mpPreviousPlanRename,
                          ),
                          onSelected: () => _rename(context, ref, plan),
                        ),
                        OverflowMenuItem(
                          key: const ValueKey(
                            'meal_planning.previous_plan_use_again',
                          ),
                          label: content.getValue(
                            ContentKeys.mpPreviousPlanUseAgain,
                          ),
                          onSelected: () => _useAgain(context, ref),
                        ),
                        OverflowMenuItem(
                          key: const ValueKey(
                            'meal_planning.previous_plan_delete',
                          ),
                          label: content.getValue(ContentKeys.mpPlanDelete),
                          destructive: true,
                          onSelected: () => _delete(context, ref),
                        ),
                      ],
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
                    : _PlanRows(plan: plan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  EarlierPlan _notifier(WidgetRef ref) =>
      ref.read(earlierPlanProvider(planId).notifier);

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    MealPlan plan,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: plan.name ?? ''),
    );
    if (name == null || !context.mounted) return;
    await _run(context, ref, () => _notifier(ref).rename(name));
  }

  Future<void> _useAgain(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    final copy = await _run(context, ref, () => _notifier(ref).useAgain());
    if (copy == null || !context.mounted) return;
    MealvanaSnackbar.showSuccess(
      context,
      content.getValue(ContentKeys.mpPreviousPlanUseAgainDone),
    );
    // The draft opens in this view, where its Confirm makes it this week's.
    context.pushReplacement('/food/plans/${copy.id}');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('meal_planning.previous_plan_delete_confirm'),
        backgroundColor: Theme.of(dialogContext).scaffoldBackgroundColor,
        title: Text(content.getValue(ContentKeys.mpPlanDeleteTitle)),
        content: Text(content.getValue(ContentKeys.mpPreviousPlanDeleteBody)),
        actions: [
          TextButton(
            key: const ValueKey('meal_planning.previous_plan_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(content.getValue(ContentKeys.mpPlanDeleteCancel)),
          ),
          TextButton(
            key: const ValueKey('meal_planning.previous_plan_delete_go'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              content.getValue(ContentKeys.mpPlanDeleteConfirm),
              style: const TextStyle(color: AppColors.dragonfruitLight),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final done = await _run(context, ref, () async {
      await _notifier(ref).delete();
      return true;
    });
    if (done != true || !context.mounted) return;
    MealvanaSnackbar.showInfo(
      context,
      content.getValue(ContentKeys.mpPlanDeleted),
    );
    context.pop();
  }
}

/// Runs a write and says what went wrong, if anything: offline is a
/// warning, anything else the server error. `null` when it failed.
Future<T?> _run<T>(
  BuildContext context,
  WidgetRef ref,
  Future<T> Function() write,
) async {
  final content = ref.read(contentServiceProvider);
  try {
    return await write();
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
  return null;
}

/// The plan's name, typed in place; Save hands back what was typed (the
/// server trims it, and an empty name clears it back to the week).
class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    return AlertDialog(
      key: const ValueKey('meal_planning.previous_plan_rename_dialog'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(content.getValue(ContentKeys.mpPreviousPlanRenameTitle)),
      content: TextField(
        key: const ValueKey('meal_planning.previous_plan_rename_field'),
        controller: _text,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: content.getValue(ContentKeys.mpPreviousPlanRenameHint),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          key: const ValueKey('meal_planning.previous_plan_rename_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(content.getValue(ContentKeys.mpPreviousPlanRenameCancel)),
        ),
        TextButton(
          key: const ValueKey('meal_planning.previous_plan_rename_save'),
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(content.getValue(ContentKeys.mpPreviousPlanRenameSave)),
        ),
      ],
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

/// The plan's rows as [PlanTile]s, each with its ⋮ (Remove) and a servings
/// stepper under it, then Confirm when the plan is a draft.
class _PlanRows extends ConsumerWidget {
  const _PlanRows({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final showMacros =
        ref.watch(vanaSettingsControllerProvider).value?.showMacros ?? true;
    final slots = ref.planPhotoSlots(plan.meals);
    final notifier = ref.read(earlierPlanProvider(plan.id).notifier);

    return ListView(
      key: const ValueKey('meal_planning.previous_plan_rows'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        for (final (i, meal) in plan.meals.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          PlanTile(
            key: ValueKey('meal_planning.previous_plan_tile_${meal.id}'),
            meal: meal,
            slot: slots[meal.id],
            showMacros: showMacros,
            onTap: () => context.push(
              '/food/meals/${meal.libraryMealId ?? meal.savedMealId ?? meal.id}',
            ),
            onRemove: () =>
                _run(context, ref, () => notifier.removeMeal(meal.id)),
          ),
          Row(
            key: ValueKey('meal_planning.previous_plan_servings_${meal.id}'),
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                content.getValue(ContentKeys.mpServingsLabel),
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ServingsStepper(
                value: meal.servings,
                onChanged: (servings) => _run(
                  context,
                  ref,
                  () => notifier.setServings(meal.id, servings),
                ),
              ),
            ],
          ),
        ],
        if (plan.isDraft && plan.meals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _ConfirmDraftButton(planId: plan.id),
        ],
      ],
    );
  }
}

/// Confirm on a draft opened here: it becomes this week's plan, replacing
/// the one there the same way any new plan does (mp-675), and the view
/// closes back to the Plan tab.
class _ConfirmDraftButton extends ConsumerStatefulWidget {
  const _ConfirmDraftButton({required this.planId});

  final String planId;

  @override
  ConsumerState<_ConfirmDraftButton> createState() =>
      _ConfirmDraftButtonState();
}

class _ConfirmDraftButtonState extends ConsumerState<_ConfirmDraftButton> {
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
        setState(() => _busy = true);
        final done = await _run(context, ref, () async {
          await ref.read(earlierPlanProvider(widget.planId).notifier).confirm();
          return true;
        });
        if (mounted) setState(() => _busy = false);
        if (done != true || !context.mounted) return;
        MealvanaSnackbar.showSuccess(
          context,
          content.getValue(ContentKeys.mpConfirmedToast),
        );
        context.pop();
      },
    );
  }
}
