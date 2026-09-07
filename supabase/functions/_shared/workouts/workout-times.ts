/**
 * The two-time model for workout rows (RULED, Xuan 2026-08-14; mark-done
 * write revised by Q-D7 / Q-018, Xuan 2026-08-18 — SSOT:
 * docs/ssot/spec/daily-macros/platform-resolution.md, two-time model v2).
 *
 * Every session row carries `planned_time` and `actual_time` (nullable),
 * never conflated:
 *   planned_time : set at scheduling; the swipe gesture NEVER writes it
 *   actual_time  : written by Garmin sync (measured start) or mark-done
 *                  (= planned_time — the confirmation says "it happened as
 *                  planned", never the wall clock); CLEARED by mark-undone
 * Display shows `actual_time ?? planned_time`.
 *
 * Times are plain numbers (minutes) so the same logic serves vector
 * conformance, edge functions (epoch minutes) and any port.
 */

export interface WorkoutTimes {
  planned_time_min: number | null;
  actual_time_min: number | null;
}

/**
 * Mark-done writes actual_time = planned_time; planned_time is immutable
 * (G1, Q-D7 — reverses W-7's `= now`). `_now_min` is accepted so the vector
 * harness can prove it is NOT an input to the write (`two-time-mark-done`,
 * `two-time-mark-done-after-planned` sit on both sides of the boundary).
 */
export function applyMarkDone(
  times: WorkoutTimes,
  _now_min: number,
): WorkoutTimes {
  return {
    planned_time_min: times.planned_time_min,
    actual_time_min: times.planned_time_min,
  };
}

/** Mark-undone clears actual_time — back to null, not zero (G2). */
export function applyMarkUndone(times: WorkoutTimes): WorkoutTimes {
  return { planned_time_min: times.planned_time_min, actual_time_min: null };
}

/**
 * A later Garmin sync overwrites any mark-done actual_time with the measured
 * start (MANUAL → GARMIN upgrade, same as the kcal path).
 */
export function applyGarminSyncStart(
  times: WorkoutTimes,
  measured_start_min: number,
): WorkoutTimes {
  return {
    planned_time_min: times.planned_time_min,
    actual_time_min: measured_start_min,
  };
}

/** The card shows actual_time when present, else planned_time. */
export function displayTimeMin(times: WorkoutTimes): number | null {
  return times.actual_time_min ?? times.planned_time_min;
}
