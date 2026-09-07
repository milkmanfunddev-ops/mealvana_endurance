/// Titles and window labels for the pre-workout (BEFORE) feeding cards.
///
/// SSOT: `docs/ssot/spec/design/components/feeding-card.md` v1 — "Tier ×
/// title × window label × what it carries" and FC-1. Pure functions; the
/// engine emits no window strings and no `renderAs`, so deriving them is the
/// consumer's job.
///
/// * `MEAL`    → **Pre-Run Meal** — always, for every sport, never renamed
///               (FC-1 as ratified; deferred-ledger P4 retires the former
///               sport-varying "Pre-Ride Meal" / "Pre-Workout Meal" variants)
/// * `SNACK`   → **Light Meal** iff its carb aim ≥ `LIGHT_MEAL_G_PER_KG·BW`
///               (carbs v2, 1.0 g/kg), else **Pre-Workout Snack**
/// * `TOP_OFF` → **Top-Off**
///
/// Window labels (uppercase in the rendering):
///
/// * meal    → "FINISH BY 2H OUT", plus " (15 MIN WINDOW)" when the plan's
///             lead is 2 h – 2 h 15
/// * snack   → "2H TO 30 MIN OUT", or "NOW UNTIL 30 MIN OUT" when it is the
///             first extant feeding
/// * top-off → "LAST 30 MIN", or "NOW UNTIL THE START" when it is the first
///             extant feeding (t > 0), or "NOW" at the start line (t = 0)
library;

/// The three pre-workout feeding tiers (carbs v2 / hydration v6 tier names).
enum PreWorkoutFeedingTier {
  meal('meal'),
  snack('snack'),
  topOff('top_off');

  const PreWorkoutFeedingTier(this.engineName);

  /// The engine's tier string (`meal` · `snack` · `top_off`).
  final String engineName;

  /// The plan sub-phase type used by `BeforeSubPhase.subPhaseType`
  /// (`meal` · `snack` · `top_up`).
  String get subPhaseType =>
      this == PreWorkoutFeedingTier.topOff ? 'top_up' : engineName;

  /// Parse either spelling (`top_off` from the engine, `top_up` from the
  /// plan). Returns null for an unrecognised tier.
  static PreWorkoutFeedingTier? parse(String? raw) {
    switch (raw) {
      case 'meal':
        return PreWorkoutFeedingTier.meal;
      case 'snack':
        return PreWorkoutFeedingTier.snack;
      case 'top_off':
      case 'top_up':
      case 'topoff':
        return PreWorkoutFeedingTier.topOff;
      default:
        return null;
    }
  }
}

/// `LIGHT_MEAL_G_PER_KG` — carbs v2 constant: a snack at or above this renders
/// as "Light Meal".
const double kLightMealGPerKg = 1.0;

/// `T_REF` / `TIER_MEAL_MIN` (both 120) and `TIER_TOPOFF_MAX` (30) — the tier
/// boundaries the window labels read. Numerically pinned to the engine by
/// `OfflineMacroCalculator.assertCrossSpecPin`.
const double kTierMealMin = 120.0;
const double kTierTopOffMax = 30.0;

/// Upper edge of the "(15 MIN WINDOW)" annotation on the meal label.
const double kMealFifteenMinWindowMax = 135.0;

/// Title for a feeding card (FC-1).
///
/// [snackCarbAimG] is the SNACK tier's engine aim (`tiers[].carbsG`) and
/// [bodyWeightKg] the athlete's weight; both are needed only for the SNACK
/// naming threshold. When either is absent the threshold cannot be evaluated
/// and the snack falls back to "Pre-Workout Snack".
String preWorkoutFeedingTitle(
  PreWorkoutFeedingTier tier, {
  double? snackCarbAimG,
  double? bodyWeightKg,
}) {
  switch (tier) {
    case PreWorkoutFeedingTier.meal:
      return 'Pre-Run Meal';
    case PreWorkoutFeedingTier.snack:
      if (snackCarbAimG != null &&
          bodyWeightKg != null &&
          bodyWeightKg > 0 &&
          snackCarbAimG >= kLightMealGPerKg * bodyWeightKg) {
        return 'Light Meal';
      }
      return 'Pre-Workout Snack';
    case PreWorkoutFeedingTier.topOff:
      return 'Top-Off';
  }
}

/// The small uppercase window line under a feeding-card title.
///
/// [timeBeforeMin] is the plan's frozen lead time; [isFirstFeeding] whether
/// this tier is the earliest feeding the plan carries.
String preWorkoutWindowLabel(
  PreWorkoutFeedingTier tier, {
  required double timeBeforeMin,
  required bool isFirstFeeding,
}) {
  switch (tier) {
    case PreWorkoutFeedingTier.meal:
      final fifteen =
          timeBeforeMin >= kTierMealMin &&
          timeBeforeMin <= kMealFifteenMinWindowMax;
      return fifteen ? 'FINISH BY 2H OUT (15 MIN WINDOW)' : 'FINISH BY 2H OUT';
    case PreWorkoutFeedingTier.snack:
      return isFirstFeeding ? 'NOW UNTIL 30 MIN OUT' : '2H TO 30 MIN OUT';
    case PreWorkoutFeedingTier.topOff:
      if (!isFirstFeeding) return 'LAST 30 MIN';
      return timeBeforeMin <= 0 ? 'NOW' : 'NOW UNTIL THE START';
  }
}
