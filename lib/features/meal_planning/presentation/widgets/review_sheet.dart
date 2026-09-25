import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../../shared/widgets/kyle_design/data/macro_pill_row.dart';
import '../../application/plan_meal_photos.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/cooking_session.dart';
import '../../domain/meal_plan.dart';
import '../../domain/meal_plan_status.dart';
import '../../domain/plan_meal.dart';
import 'dashed_box.dart';
import 'meal_photo_view.dart';
import 'session_chip.dart';
import 'slot_chip.dart';
import 'stepper.dart';

/// "Review plan" sheet: what the week adds up to, then the meals grouped by
/// cooking session when batch cooking is on (else flat), each with a stepper
/// and a ×, and the Confirm button — disabled once the plan is confirmed
/// (05 §4). Confirm is remote-ack: the caller
/// awaits [onConfirm], gates the "confirmed" transition on it, and this
/// sheet surfaces failures. [onConfirm] throws when the confirm did not
/// land: the sheet stays open on the draft and says why under the button,
/// "Needs a connection" or the server error (testing-wave 129, 88-015).
///
/// [showMacros] puts a compact [MacroPillRow] under each meal's slot chip
/// (on by default — the `show_macros` default, plan §4.2). No plan-level
/// total: the sheet does no arithmetic (macro-pill-row MP-5).
///
/// [livePlan], when given, is what the sheet renders from while it is open,
/// so a stepper or Remove shows at once and Confirm confirms what is on
/// screen (testing-wave 88-004); [plan] is the plan it opened with and the
/// fallback while [livePlan] has none.
Future<void> showReviewSheet({
  required BuildContext context,
  required WidgetRef ref,
  required MealPlan plan,
  required ValueChanged<PlanMeal> onTapMeal,
  required void Function(PlanMeal meal, int servings) onServings,
  required ValueChanged<PlanMeal> onRemove,
  required Future<void> Function() onConfirm,

  /// Ran after a successful confirm, once the sheet has popped — hosts use
  /// it to land the athlete somewhere useful (the chat screen goes to the
  /// shopping list). When null the sheet shows the confirmed toast itself;
  /// when provided, the navigation is the confirmation.
  VoidCallback? onConfirmed,
  bool showMacros = true,
  ProviderListenable<MealPlan?>? livePlan,
}) {
  final content = ref.read(contentServiceProvider);
  return showAdaptiveModal<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _ReviewSheet(
        content: content,
        plan: plan,
        livePlan: livePlan,
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
    this.livePlan,
    required this.onTapMeal,
    required this.onServings,
    required this.onRemove,
    required this.onConfirm,
    this.onConfirmed,
    this.showMacros = true,
  });

  final ContentService content;
  final MealPlan plan;
  final ProviderListenable<MealPlan?>? livePlan;
  final bool showMacros;
  final ValueChanged<PlanMeal> onTapMeal;
  final void Function(PlanMeal meal, int servings) onServings;
  final ValueChanged<PlanMeal> onRemove;
  final Future<void> Function() onConfirm;
  final VoidCallback? onConfirmed;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  bool _confirming = false;

  /// Why the last Confirm did not land, shown under the button until the
  /// next tap.
  String? _confirmFailure;

  /// What the sheet shows: the live plan when the host gave one, else the
  /// plan it opened with. Set at the top of every [build].
  late MealPlan _plan;

  List<(String?, List<PlanMeal>)> get _groups {
    if (!_plan.batchCooking) {
      return [(null, _plan.meals)];
    }
    final bySession = <CookingSession?, List<PlanMeal>>{};
    for (final meal in _plan.meals) {
      bySession.putIfAbsent(meal.session, () => []).add(meal);
    }
    // Stable order: the three sessions, then session-less rows.
    return [
      for (final s in CookingSession.values)
        if (bySession.containsKey(s)) (s, bySession.remove(s)!),
      if (bySession.containsKey(null)) (null, bySession.remove(null)!),
    ].map((e) => (_sessionLabel(e.$1), e.$2)).toList();
  }

  /// "Cook Monday" — the day the session falls on in this plan's period,
  /// derived from its week start and period length (mp-269).
  String? _sessionLabel(CookingSession? session) => session == null
      ? null
      : SessionChip.labelInPlan(widget.content, session, _plan);

  /// What the plan covers, in the athlete's own mode (mp-231 clauses 3–4): a
  /// batch is cooked once and eaten across the period, so it fills servings;
  /// an athlete who cooks the night of fills nights.
  String _coverageLine() {
    final coverage = _plan.coverage;
    return ContentKeys.format(
      widget.content.getValue(
        _plan.batchCooking
            ? ContentKeys.mpReviewCoverageServings
            : ContentKeys.mpReviewCoverageNights,
      ),
      {
        'covered': coverage.covered,
        'slots': coverage.lunchDinnerSlots,
        'days': coverage.periodDays,
      },
    );
  }

  /// "Your week" over seven days, "Your 10 days" over any other period.
  String _title() {
    final days = _plan.coverage.periodDays;
    return days == 7
        ? widget.content.getValue(ContentKeys.mpReviewYourWeek)
        : ContentKeys.format(
            widget.content.getValue(ContentKeys.mpReviewYourPeriod),
            {'n': days},
          );
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() {
      _confirming = true;
      _confirmFailure = null;
    });
    String? failure;
    try {
      await widget.onConfirm();
    } on Exception catch (e) {
      failure = widget.content.getValue(
        isConnectionFailure(e)
            ? ContentKeys.mpNeedsConnection
            : ContentKeys.mpServerError,
      );
    }
    if (!mounted) return;
    if (failure == null) {
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
      // The draft stays as it was; the line says why (88-015).
      setState(() {
        _confirming = false;
        _confirmFailure = failure;
      });
    }
  }

  /// "1 meal · 1 serving", "2 meals · 5 servings": each count singular for
  /// one (16-004).
  String _summaryLine(int meals, int servings) {
    final label = widget.content;
    String count(int n, String one, String many) => n == 1
        ? label.getValue(one)
        : ContentKeys.format(label.getValue(many), {'n': n});
    return ContentKeys.format(
      label.getValue(ContentKeys.mpReviewSummaryCounts),
      {
        'meals': count(
          meals,
          ContentKeys.mpReviewMealsOne,
          ContentKeys.mpReviewMeals,
        ),
        'servings': count(
          servings,
          ContentKeys.mpReviewServingsOne,
          ContentKeys.mpReviewServings,
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.livePlan;
    _plan = (live == null ? null : ref.watch(live)) ?? widget.plan;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final confirmed = _plan.status == MealPlanStatus.confirmed;
    final label = widget.content;

    final totalServings = _plan.meals.fold<int>(
      0,
      (sum, m) => sum + m.servings,
    );

    // Each row's picture is its library Meal's current Dish photo, read by
    // meal id — the same answer the plan tile and the plan bar get, so the
    // grouping below cannot change what a row shows (ADR 0003).
    final slots = ref.planPhotoSlots(_plan.meals);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What the week adds up to, before the meal-by-meal list.
            Text(
              _title(),
              key: const ValueKey('meal_planning.review_sheet.title'),
              style: AppTextStyles.sectionTitle.copyWith(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _summaryLine(_plan.meals.length, totalServings),
              key: const ValueKey('meal_planning.review_sheet.summary'),
              style: AppTextStyles.bodyMedium.copyWith(color: secondary),
            ),
            const SizedBox(height: 2),
            Text(
              _coverageLine(),
              key: const ValueKey('meal_planning.review_sheet.coverage'),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_plan.meals.isEmpty)
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
                                MealPhotoThumb(
                                  photo: slots[meal.id]?.photo,
                                  size: 36,
                                  gap: 8,
                                  borderRadius: BorderRadius.circular(9),
                                ),
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
                    : ContentKeys.mpReviewConfirm,
              ),
              height: 48,
              isLoading: _confirming,
              onPressed: confirmed || _plan.meals.isEmpty ? null : _confirm,
            ),
            if (_confirmFailure case final failure?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                failure,
                key: const ValueKey(
                  'meal_planning.review_sheet.confirm_failed',
                ),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.orange,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            KyleSecondaryButton(
              key: const ValueKey('meal_planning.review_sheet.keep_planning'),
              text: label.getValue(ContentKeys.mpReviewKeepPlanning),
              height: 48,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
