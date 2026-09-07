import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/data/macro_pill_row.dart';
import '../../application/meal_icon_classifier.dart';
import '../../domain/cooking_session.dart';
import '../../domain/meal_plan.dart';
import '../../domain/meal_plan_status.dart';
import '../../domain/plan_meal.dart';
import 'choice_chip_button.dart';
import 'dashed_box.dart';
import 'meal_icon_glyphs.dart';
import 'slot_chip.dart';
import 'stepper.dart';

/// "Review plan" sheet: what the week adds up to, then the meals grouped by
/// cooking session when batch cooking is on (else flat), each with a stepper
/// and a ×, and the Confirm button — disabled once the plan is confirmed
/// (05 §4). Confirm is remote-ack: the caller
/// awaits [onConfirm], gates the "confirmed" transition on it, and this
/// sheet surfaces failures.
///
/// [showMacros] puts a compact [MacroPillRow] under each meal's slot chip
/// (on by default — the `show_macros` default, plan §4.2). No plan-level
/// total: the sheet does no arithmetic (macro-pill-row MP-5).
Future<void> showReviewSheet({
  required BuildContext context,
  required WidgetRef ref,
  required MealPlan plan,
  required ValueChanged<PlanMeal> onTapMeal,
  required void Function(PlanMeal meal, int servings) onServings,
  required ValueChanged<PlanMeal> onRemove,
  required Future<bool> Function() onConfirm,

  /// Ran after a successful confirm, once the sheet has popped — hosts use
  /// it to land the athlete somewhere useful (the chat screen goes to the
  /// shopping list). When null the sheet shows the confirmed toast itself;
  /// when provided, the navigation is the confirmation.
  VoidCallback? onConfirmed,
  bool showMacros = true,
}) {
  final content = ref.read(contentServiceProvider);
  return showAdaptiveModal<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _ReviewSheet(
        content: content,
        plan: plan,
        showMacros: showMacros,
        onTapMeal: onTapMeal,
        onServings: onServings,
        onRemove: onRemove,
        onConfirm: onConfirm,
        onConfirmed: onConfirmed,
      );
    },
  );
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({
    required this.content,
    required this.plan,
    required this.onTapMeal,
    required this.onServings,
    required this.onRemove,
    required this.onConfirm,
    this.onConfirmed,
    this.showMacros = true,
  });

  final ContentService content;
  final MealPlan plan;
  final bool showMacros;
  final ValueChanged<PlanMeal> onTapMeal;
  final void Function(PlanMeal meal, int servings) onServings;
  final ValueChanged<PlanMeal> onRemove;
  final Future<bool> Function() onConfirm;
  final VoidCallback? onConfirmed;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  bool _confirming = false;

  List<(String?, List<PlanMeal>)> get _groups {
    if (!widget.plan.batchCooking) {
      return [(null, widget.plan.meals)];
    }
    final bySession = <CookingSession?, List<PlanMeal>>{};
    for (final meal in widget.plan.meals) {
      bySession.putIfAbsent(meal.session, () => []).add(meal);
    }
    // Stable order: the three sessions, then session-less rows.
    return [
      for (final s in CookingSession.values)
        if (bySession.containsKey(s)) (s, bySession.remove(s)!),
      if (bySession.containsKey(null)) (null, bySession.remove(null)!),
    ].map((e) => (_sessionLabel(e.$1), e.$2)).toList();
  }

  String? _sessionLabel(CookingSession? session) => switch (session) {
    CookingSession.cookSun => widget.content.getValue(
      ContentKeys.mpSessionCookSun,
    ),
    CookingSession.topupWed => widget.content.getValue(
      ContentKeys.mpSessionTopupWed,
    ),
    CookingSession.freshFri => widget.content.getValue(
      ContentKeys.mpSessionFreshFri,
    ),
    null => null,
  };

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    final ok = await widget.onConfirm();
    if (!mounted) return;
    if (ok) {
      final navigator = Navigator.of(context);
      final onConfirmed = widget.onConfirmed;
      if (onConfirmed == null) {
        MealvanaSnackbar.showSuccess(
          context,
          widget.content.getValue(ContentKeys.mpConfirmedToast),
        );
      }
      navigator.pop();
      // After the pop so the host navigates from a clean stack (the chat
      // screen leaves for the shopping list).
      onConfirmed?.call();
    } else {
      setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final confirmed = widget.plan.status == MealPlanStatus.confirmed;
    final label = widget.content;

    final totalServings = widget.plan.meals.fold<int>(
      0,
      (sum, m) => sum + m.servings,
    );
    final types = <String>{
      for (final m in widget.plan.meals)
        SlotChip.shortLabelFor(label, m.mealType),
    };
    final howLabel = label.getValue(
      widget.plan.batchCooking
          ? ContentKeys.mpReviewGrouped
          : ContentKeys.mpReviewNightOf,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What the week adds up to, before the meal-by-meal list.
            Text(
              label.getValue(ContentKeys.mpReviewYourWeek).toUpperCase(),
              key: const ValueKey('meal_planning.review_sheet.title'),
              style: AppTextStyles.overline.copyWith(
                color: secondary,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ContentKeys.format(label.getValue(ContentKeys.mpReviewSummary), {
                'meals': widget.plan.meals.length,
                'servings': totalServings,
              }),
              style: AppTextStyles.sectionTitle.copyWith(
                color: textColor,
                fontSize: 18,
              ),
            ),
            Text(
              '${types.join(' · ')} · $howLabel',
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.plan.meals.isEmpty)
              DashedBox(
                child: Text(
                  label.getValue(ContentKeys.mpReviewEmpty),
                  style: AppTextStyles.bodyMedium.copyWith(color: secondary),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (groupLabel, meals) in _groups) ...[
                        if (groupLabel != null) ...[
                          Text(
                            groupLabel,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        for (final meal in meals)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                MealIconTile(
                                  icon:
                                      meal.icon ??
                                      MealIconClassifier.classify(
                                        name: meal.name,
                                      ),
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      widget.onTapMeal(meal);
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          meal.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.foodTitle
                                              .copyWith(
                                                color: textColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                height: 1.25,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        SlotChip(
                                          type: meal.mealType,
                                          short: true,
                                        ),
                                        if (widget.showMacros &&
                                            (meal.kcal != null ||
                                                meal.carbsG != null)) ...[
                                          const SizedBox(height: 4),
                                          MacroPillRow(
                                            kcal: meal.kcal,
                                            carbsG: meal.carbsG,
                                            proteinG: meal.proteinG,
                                            fatG: meal.fatG,
                                            compact: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ServingsStepper(
                                  value: meal.servings,
                                  dense: true,
                                  onChanged: (next) =>
                                      widget.onServings(meal, next),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 16,
                                  tooltip: label.getValue(
                                    ContentKeys.mpBtnRemove,
                                  ),
                                  onPressed: () => widget.onRemove(meal),
                                  icon: Icon(Icons.close, color: secondary),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            KylePrimaryButton(
              key: const ValueKey('meal_planning.review_sheet.confirm'),
              text: label.getValue(
                confirmed
                    ? ContentKeys.mpReviewConfirmed
                    : ContentKeys.mpBtnConfirm,
              ),
              height: 48,
              isLoading: _confirming,
              onPressed: confirmed || widget.plan.meals.isEmpty
                  ? null
                  : _confirm,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: ChoiceChipButton(
                label: label.getValue(ContentKeys.mpReviewKeepPlanning),
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
