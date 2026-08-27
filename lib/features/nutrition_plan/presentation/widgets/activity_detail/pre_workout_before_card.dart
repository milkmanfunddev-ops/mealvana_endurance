/// Design SSOT surface — **Pre-Workout BEFORE Card**.
///
/// Spec: `docs/ssot/spec/design/surfaces/pre-workout-before-card.md` **v1**
/// (RATIFIED Xuan 2026-08-26); composes the library components
/// `FuelStat` (fuel-stat v1), `FeedingCard` (feeding-card v1) and
/// `HydrationCheckControl` (hydration-check v1) from
/// `lib/shared/widgets/kyle_design/fueling/`. Reference rendering
/// `docs/ssot/spec/design/renderings/pre-workout@v2.html`.
///
/// One summary row (three fuel-stats) above the ordered feeding cards.
/// UI-only: every figure arrives in [PreWorkoutBeforeCardData] (built by
/// `PreWorkoutBeforeCardAssembler`); every write goes out through a callback
/// (B-3: a hydration answer is a whole-card update the controller applies,
/// then this surface re-renders from the new data in the same frame).
///
/// Scope guards (this iteration): S-G1 BEFORE only · S-G2 no live/current
/// window indicator · S-G3 no progress ring / counter / streak · **S-G4 the
/// `?` fine print is ABSENT** (not inert) pending the fine-print SSOT.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/kyle_design/fueling/feeding_card.dart';
import '../../../../../shared/widgets/kyle_design/fueling/fuel_stat.dart';
import '../../../../../shared/widgets/kyle_design/fueling/fueling_glyphs.dart';
import '../../../../../shared/widgets/kyle_design/fueling/hydration_check_control.dart';
import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../domain/pre_workout_before_card_model.dart';
import '../../../domain/pre_workout_hydration_check.dart';

class PreWorkoutBeforeCard extends StatelessWidget {
  const PreWorkoutBeforeCard({
    super.key,
    required this.data,
    required this.onStep,
    required this.onAddFood,
    required this.onAnswerHydrationCheck,
    required this.onChangeHydrationAnswer,
    this.title = 'BEFORE',
    this.initiallyExpandedTiers = const {},
    this.hydrationCheckInitiallyExpanded = false,
  });

  final PreWorkoutBeforeCardData data;

  /// FC-G2 → the controller: a row's quantity changed (0 = remove the row,
  /// deferred-ledger P3).
  final void Function(FeedingFoodRow row, double newQuantity) onStep;

  /// FC-7 → the controller, with the sub-phase category.
  final ValueChanged<String> onAddFood;

  /// H-2 → the controller (recompute + tagged row, one atomic write).
  final ValueChanged<HydrationCheckAnswer> onAnswerHydrationCheck;

  /// H-3 → the controller (exact revert).
  final VoidCallback onChangeHydrationAnswer;

  final String title;

  /// Engine tier names (`meal` · `snack` · `top_off`) to render expanded.
  final Set<String> initiallyExpandedTiers;
  final bool hydrationCheckInitiallyExpanded;

  static const Key rootKey = Key('pre_workout_before_card');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: rootKey,
      decoration: BoxDecoration(
        border: Border.all(color: orangeAlpha(.8)),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.fromLTRB(15, 17, 15, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: "BEFORE". The `?` fine-print control is deliberately
          // absent (S-G4) — no node, not an inert one.
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTextStyles.sansita,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: 22 * .02,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: FuelStat(data: data.carbs)),
              const SizedBox(width: 10),
              Expanded(child: FuelStat(data: data.fluids)),
              const SizedBox(width: 10),
              Expanded(child: FuelStat(data: data.sodium)),
            ],
          ),
          for (final feeding in data.feedings) ...[
            const SizedBox(height: 14),
            FeedingCard(
              key: ValueKey('before.${feeding.tier.engineName}'),
              data: feeding,
              initiallyExpanded: initiallyExpandedTiers.contains(
                feeding.tier.engineName,
              ),
              onStep: onStep,
              onAddFood: onAddFood,
              hydrationCheck:
                  (feeding.hostsHydrationCheck && data.hydrationCheck != null)
                  ? HydrationCheckControl(
                      state: data.hydrationCheck!,
                      initiallyExpanded: hydrationCheckInitiallyExpanded,
                      onAnswer: onAnswerHydrationCheck,
                      onChangeAnswer: onChangeHydrationAnswer,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
