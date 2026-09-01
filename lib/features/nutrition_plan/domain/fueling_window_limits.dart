/// SSOT input domain for the pre-workout fueling window ("time before
/// workout") collected by the new-activity steppers.
///
/// Ratified in `docs/ssot/spec/fueling/pre-workout-carbs.md` §Inputs and
/// deviation D-016 (`docs/ssot/DEVIATIONS.md`): lead time is **0–240 minutes
/// in 15-minute steps** — seventeen values. The 240-minute ceiling is a
/// product decision (Xuan, 2026-08-04); the app's former 480-minute stepper
/// let the carb band silently reach 4.5 g/kg above t−240, the exact v1
/// defect carbs v2 removes.
///
/// Every lead-time stepper MUST take its bounds from here, and every value
/// read back from persistence (activities saved before the cap existed can
/// carry up to 480) MUST pass through [clampFuelingWindowMinutes] before it
/// reaches form state or the engine.
abstract final class FuelingWindowLimits {
  /// Minimum lead time in minutes (inclusive).
  static const int minMinutes = 0;

  /// Maximum lead time in minutes (inclusive) — the ratified D-016 ceiling.
  static const int maxMinutes = 240;

  /// Stepper increment in minutes.
  static const int stepMinutes = 15;
}

/// Clamps a lead time into the ratified 0–240 domain. Apply to any
/// persisted or externally-supplied value before it enters form state, so a
/// stale pre-D-016 activity (e.g. 480 min) renders a reachable stepper value
/// and never feeds an out-of-domain input onward.
int clampFuelingWindowMinutes(int minutes) => minutes.clamp(
  FuelingWindowLimits.minMinutes,
  FuelingWindowLimits.maxMinutes,
);
