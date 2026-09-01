/// Display units for the pre-workout (BEFORE) card — R-01 (fl oz) and M-5
/// (whole grams).
///
/// SSOT: `docs/ssot/spec/design/components/fuel-stat.md` v1 M-5 and the R-01
/// ruling (reconciliation §4, Xuan 2026-08-26): the engine emits exact ml / g
/// and never rounds; the card converts at the display edge only.
///
/// * fluid **target** → `round(ml / 29.5735)` oz
/// * fluid **band ends** → `[floor, ceil]` in oz — the band always widens,
///   never narrows, so rounding cannot turn a compliant athlete into a
///   failing one
/// * carbohydrate → whole grams (nearest)
///
/// R-01 worked pairs pinned by test: 487.5 ml → 16 oz, 756 ml → 26 oz.
///
/// This supersedes the retired `pre_workout_display_rounding.dart`
/// (25-ml / 5-g rules from notes §6 — P5 in the deferred ledger: the newer
/// ratified documents win).
library;

/// One US fluid ounce in millilitres (R-01's constant, verbatim).
const double kMlPerFlOz = 29.5735;

/// Fluid **target** in whole oz — `round(ml / 29.5735)`.
int flOzTarget(double ml) => (ml / kMlPerFlOz).round();

/// Fluid band **floor** in whole oz — rounded down so the band never narrows.
int flOzFloor(double ml) => (ml / kMlPerFlOz).floor();

/// Fluid band **ceiling** in whole oz — rounded up so the band never narrows.
int flOzCeil(double ml) => (ml / kMlPerFlOz).ceil();

/// A delivered fluid figure in whole oz (same rule as the target).
int flOzDelivered(double ml) => flOzTarget(ml);

/// Carbohydrate (or sodium) figure to the whole unit (M-5: carbs to the gram
/// on this surface).
int wholeUnits(double value) => value.round();
