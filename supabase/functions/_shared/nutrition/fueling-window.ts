/**
 * Fueling-window authority — food-recommendation §3/§3a (RATIFIED Xuan,
 * 2026-09-03). TS twin of
 * `lib/features/nutrition_plan/domain/fueling_window_authority.dart` (§8 twin
 * contract — every rule binds both engines; a fix landing in one twin is a
 * defect until ported).
 *
 * The ratified timing table provides the DEFAULT pre-workout window; the
 * client's retired `recommendedHoursBefore` formula is superseded. The engine
 * side consumes the resulting `hours_before` on the wire; this module is the
 * server's own copy of the authority so the two engines can be run
 * differentially over the ratified vectors (and so any future server-side
 * defaulting reads the same table).
 *
 * Rules: §3a table (race 180 · ≥2.5 h 180 · 1.5–2.5 h 150 · 60–90 moderate+
 * 120 · 60–90 easy 60 · <60 45) · early-start overlay (training strictly
 * before 07:00 drops to 60 min; races exempt; never raises) · the §3 clamp
 * (window ≤ minutes-until-start, floor 15; unreachable tiers not offered) ·
 * tier thresholds meal ≥ 120 / snack ≥ 30 / top-up always.
 */

export type FuelingSessionClass =
  | "race"
  | "long>=2.5h"
  | "mid1.5-2.5h"
  | "60-90-moderate"
  | "60-90-easy"
  | "<60";

export const EARLY_START_HOUR_EXCLUSIVE = 7;
export const EARLY_START_WINDOW_MIN = 60;
export const FUELING_WINDOW_FLOOR_MIN = 15;
export const TIER_MEAL_MIN_MIN = 120;
export const TIER_SNACK_MIN_MIN = 30;

export function tableDefaultWindowMin(
  sessionClass: FuelingSessionClass,
): number {
  switch (sessionClass) {
    case "race":
    case "long>=2.5h":
      return 180;
    case "mid1.5-2.5h":
      return 150;
    case "60-90-moderate":
      return 120;
    case "60-90-easy":
      return 60;
    case "<60":
      return 45;
  }
}

export interface FuelingWindowResolution {
  windowMin: number;
  activePhases: string[];
}

export function resolveFuelingWindow(args: {
  sessionClass: FuelingSessionClass;
  startHour: number;
  isRace: boolean;
  minutesUntilStart: number;
}): FuelingWindowResolution {
  let window = tableDefaultWindowMin(args.sessionClass);

  if (!args.isRace && args.startHour < EARLY_START_HOUR_EXCLUSIVE) {
    window = Math.min(window, EARLY_START_WINDOW_MIN);
  }

  if (args.minutesUntilStart < window) window = args.minutesUntilStart;
  if (window < FUELING_WINDOW_FLOOR_MIN) window = FUELING_WINDOW_FLOOR_MIN;

  const activePhases: string[] = [];
  if (window >= TIER_MEAL_MIN_MIN) activePhases.push("meal");
  if (window >= TIER_SNACK_MIN_MIN) activePhases.push("snack");
  activePhases.push("top_up");

  return { windowMin: window, activePhases };
}
