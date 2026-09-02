import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/cooking_session.dart';
import '../../domain/meal_plan.dart';
import '../../domain/meal_plan_status.dart';
import '../../domain/plan_meal.dart';
import 'plan_tile.dart';
import 'stepper.dart';

/// "Review plan" sheet: meals grouped by cooking session when batch cooking
/// is on (else flat), per-meal steppers, and the Confirm button — disabled
/// once the plan is confirmed (05 §4). Confirm is remote-ack: the caller
/// awaits [onConfirm], gates the "confirmed" transition on it, and this
/// sheet surfaces failures.
Future<void> showReviewSheet({
  required BuildContext context,
  required WidgetRef ref,
  required MealPlan plan,
  required ValueChanged<PlanMeal> onTapMeal,
  required void Function(PlanMeal meal, int servings) onServings,
  required Future<bool> Function() onConfirm,
}) {
  final content = ref.read(contentServiceProvider);
  return showAdaptiveModal<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _ReviewSheet(
        content: content,
        plan: plan,
        onTapMeal: onTapMeal,
        onServings: onServings,
        onConfirm: onConfirm,
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
    required this.onConfirm,
  });

  final ContentService content;
  final MealPlan plan;
  final ValueChanged<PlanMeal> onTapMeal;
  final void Function(PlanMeal meal, int servings) onServings;
  final Future<bool> Function() onConfirm;

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
      MealvanaSnackbar.showSuccess(
        context,
        widget.content.getValue(ContentKeys.mpConfirmedToast),
      );
      Navigator.of(context).pop();
    } else {
      setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final confirmed = widget.plan.status == MealPlanStatus.confirmed;
    final label = widget.content;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.getValue(confirmed
                  ? ContentKeys.mpReviewConfirmed
                  : ContentKeys.mpReviewTitle),
              key: const ValueKey('meal_planning.review_sheet.title'),
              style: AppTextStyles.sectionTitle.copyWith(color: textColor),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (groupLabel, meals) in _groups) ...[
                      if (groupLabel != null) ...[
                        Text(
                          groupLabel,
                          style: AppTextStyles.smallLabel.copyWith(
                            color: secondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      for (final meal in meals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            children: [
                              Expanded(
                                child: PlanTile(
                                  meal: meal,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onTapMeal(meal);
                                  },
                                ),
                              ),
                              ServingsStepper(
                                value: meal.servings,
                                onChanged: (next) =>
                                    widget.onServings(meal, next),
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
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('meal_planning.review_sheet.confirm'),
                onPressed: confirmed || _confirming
                    ? null
                    : _confirm,
                style: TextButton.styleFrom(
                  backgroundColor: accent.withValues(
                    alpha: confirmed || _confirming ? 0.3 : 0.16,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
                child: _confirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        label.getValue(ContentKeys.mpReviewConfirm),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.blackberry,
                          fontWeight: FontWeight.w600,
                        ),
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
