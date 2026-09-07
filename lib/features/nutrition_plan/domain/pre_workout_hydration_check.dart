/// The hydration check — the athlete's urine-colour answer and the record of
/// what it wrote, persisted beside the plan.
///
/// SSOT: `docs/ssot/spec/design/components/hydration-check.md` v1 (state
/// machine + answer→effect map) over `spec/fueling/pre-workout-hydration.md`
/// v6 *The urine check* as amended by PW-021. Persistence per deferred-ledger
/// **P2** (interim default): the answer, the added water row and stepper
/// edits live in `activities.nutrition_plan_data` beside the plan, recomputed
/// client-side by `OfflineMacroCalculator`, written in one atomic write.
///
/// JSON (under `nutrition_plan_data.preWorkoutHydrationCheck`):
///
/// ```json
/// {
///   "answer": "dark",                 // pale | dark | not_yet | not_sure
///   "baselineFluidMl": 472.5,         // fluidMl BEFORE the answer (H-3 revert)
///   "baselineFluidTiers": [ {"tier": "meal", "fluidMl": 472.5}, ... ],
///   "baselineHydrationCheckUsed": "pale",
///   "addedWaterFoodId": "hydration-check-water-…"   // null when nothing added
/// }
/// ```
library;

import '../data/offline_macro_calculator.dart' show HydrationCheck;
import 'macro_targets.dart';

/// The four display answers. `none` is the TO-DO state.
///
/// The four labels collapse onto the engine's three `hydrationCheck` values
/// ([toEngineCheck]): PALE → `pale`; DARK and NOT_YET → `dark` (ACSM 2007:
/// "does not produce urine" is the dark branch); NOT_SURE → `unknown`
/// (treated as pale by v6, PROVISIONAL).
enum HydrationCheckAnswer {
  none(null),
  pale('pale'),
  dark('dark'),
  notYet('not_yet'),
  notSure('not_sure');

  const HydrationCheckAnswer(this.wireValue);

  /// Persisted value; null for [none] (which is never persisted).
  final String? wireValue;

  static HydrationCheckAnswer fromWire(String? value) {
    for (final a in HydrationCheckAnswer.values) {
      if (a.wireValue != null && a.wireValue == value) return a;
    }
    return HydrationCheckAnswer.none;
  }

  /// The engine value this answer maps to (hydration-check state table).
  HydrationCheck toEngineCheck() {
    switch (this) {
      case HydrationCheckAnswer.pale:
        return HydrationCheck.pale;
      case HydrationCheckAnswer.dark:
      case HydrationCheckAnswer.notYet:
        return HydrationCheck.dark;
      case HydrationCheckAnswer.notSure:
      case HydrationCheckAnswer.none:
        return HydrationCheck.unknown;
    }
  }

  /// True for the answers that raise the target (`+TOPUP_ML_KG·BW`).
  bool get raisesTarget => toEngineCheck() == HydrationCheck.dark;

  /// The result-line head ("Dark · target raised to 25 oz").
  String get resultHead {
    switch (this) {
      case HydrationCheckAnswer.pale:
        return 'Pale yellow';
      case HydrationCheckAnswer.dark:
        return 'Dark';
      case HydrationCheckAnswer.notYet:
        return 'Not yet';
      case HydrationCheckAnswer.notSure:
        return 'Not sure';
      case HydrationCheckAnswer.none:
        return '';
    }
  }
}

/// What an answer wrote, so Change answer can revert it exactly (H-3/H-4).
class PreWorkoutHydrationCheckRecord {
  const PreWorkoutHydrationCheckRecord({
    required this.answer,
    required this.baselineFluidMl,
    required this.baselineFluidTiers,
    required this.baselineHydrationCheckUsed,
    required this.addedWaterFoodId,
  });

  /// The answer given (never [HydrationCheckAnswer.none]).
  final HydrationCheckAnswer answer;

  /// `fluidMl` before the answer — what Change answer restores.
  final double? baselineFluidMl;

  /// `fluidTiers` before the answer.
  final List<PreRunFluidTier>? baselineFluidTiers;

  /// `hydrationCheckUsed` before the answer.
  final String? baselineHydrationCheckUsed;

  /// Id of the tagged "added by hydration check" water row, or null when
  /// nothing was added (already covered / not a dark answer).
  final String? addedWaterFoodId;

  /// True when the water row was NOT added because delivered fluid already
  /// covered the raised target (the "already covered" branch).
  bool get alreadyCovered => answer.raisesTarget && addedWaterFoodId == null;

  static const String jsonKey = 'preWorkoutHydrationCheck';

  Map<String, dynamic> toJson() => {
    'answer': answer.wireValue,
    'baselineFluidMl': baselineFluidMl,
    if (baselineFluidTiers != null)
      'baselineFluidTiers': baselineFluidTiers!.map((t) => t.toJson()).toList(),
    'baselineHydrationCheckUsed': baselineHydrationCheckUsed,
    'addedWaterFoodId': addedWaterFoodId,
  };

  static PreWorkoutHydrationCheckRecord? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final answer = HydrationCheckAnswer.fromWire(json['answer'] as String?);
    if (answer == HydrationCheckAnswer.none) return null;
    return PreWorkoutHydrationCheckRecord(
      answer: answer,
      baselineFluidMl: (json['baselineFluidMl'] as num?)?.toDouble(),
      baselineFluidTiers: (json['baselineFluidTiers'] as List<dynamic>?)
          ?.map((e) => PreRunFluidTier.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      baselineHydrationCheckUsed: json['baselineHydrationCheckUsed'] as String?,
      addedWaterFoodId: json['addedWaterFoodId'] as String?,
    );
  }
}

/// The value of `FoodItemData.origin` on the water row the check adds
/// (feeding-card FC-6: "Water (cups) · added by hydration check").
const String kHydrationCheckRowOrigin = 'hydration_check';
