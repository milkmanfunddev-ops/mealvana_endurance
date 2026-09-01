/// Display rounding for the pre-workout (BEFORE) surfaces.
///
/// The engine never rounds — `OfflineMacroCalculator.calculatePreWorkoutHydration`
/// and `calculatePreWorkoutCarbs` return exact doubles. Rounding is purely a
/// display concern and lives here, so that `487.5 ml` is never printed as
/// though it were measured.
///
/// See `docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md` §5, "UI decisions that bind the
/// engine consumer":
///
/// * fluid target → `round25`
/// * fluid band   → `[floor25(low), ceil25(high)]` — the band always widens,
///   never narrows, so a rounded floor can't turn a compliant athlete into a
///   failing one
/// * carbohydrate → nearest 5 g
library;

/// Rounds [ml] to the nearest 25 ml. Use for the fluid **target**.
double round25(double ml) => (ml / 25).round() * 25.0;

/// Rounds [ml] down to a multiple of 25 ml. Use for the fluid band **floor** —
/// rounding a floor up would narrow the permissible range.
double floor25(double ml) => (ml / 25).floorToDouble() * 25.0;

/// Rounds [ml] up to a multiple of 25 ml. Use for the fluid band **ceiling**.
double ceil25(double ml) => (ml / 25).ceilToDouble() * 25.0;

/// Rounds [grams] to the nearest 5 g. Use for every displayed carbohydrate
/// figure — the plan total and each per-feeding tier.
double round5(double grams) => (grams / 5).round() * 5.0;

/// Rounds a fluid band to `[floor25(low), ceil25(high)]`.
///
/// Returns `null` when either end is absent, so the caller renders no band at
/// all rather than a half-band.
({double low, double high})? roundFluidBand(double? lowMl, double? highMl) {
  if (lowMl == null || highMl == null) return null;
  return (low: floor25(lowMl), high: ceil25(highMl));
}

/// Rounds a carbohydrate band to the nearest 5 g at each end.
///
/// Returns `null` when either end is absent **or when the band collapses to
/// `[0, 0]`** — carbs v2 requires the `t = 0` band be suppressed, not rendered
/// as "0 – 0" (which also fabricates an "over target" state at the start line).
({double low, double high})? roundCarbBand(double? lowG, double? highG) {
  if (lowG == null || highG == null) return null;
  if (lowG == 0 && highG == 0) return null;
  return (low: round5(lowG), high: round5(highG));
}
