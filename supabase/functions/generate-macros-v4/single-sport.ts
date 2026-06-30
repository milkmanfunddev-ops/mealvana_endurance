/**
 * Single-sport macro calculation logic for generate-macros-v4.
 *
 * Contains all sport-specific calculations:
 * - During-workout nutrition (carbs, hydration)
 * - Post-workout nutrition
 * - MET and energy calculations
 * - Main calculateMacrosV4() function
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import type { PreWorkoutTemplate } from "./types.ts";
import {
  applyPreWorkoutHydrationOverlay,
  calculatePreWorkoutHydration,
  calculatePreWorkoutTargets,
  selectPreWorkoutFoods,
} from "./pre-workout.ts";
import {
  LB_TO_KG,
  IN_TO_CM,
  MI_TO_KM,
  MPH_TO_M_PER_MIN,
  toKg,
  toCm,
  toMiles,
} from "../_shared/nutrition/unit-conversions.ts";
import {
  classifyEnvironment,
  baseSweatRateFromCategory,
  sodiumConcentrationFromCategory,
  calculateActualSweatRate,
  calculateSweatRateBreakdown,
  replacementPctForDuration,
  replacementBandLabel,
} from "../_shared/nutrition/sweat-hydration.ts";

// Re-export unit conversions for other modules
export {
  LB_TO_KG,
  IN_TO_CM,
  MI_TO_KM,
  MPH_TO_M_PER_MIN,
  toKg,
  toCm,
  toMiles,
};

// Re-export hydration functions for other modules
export {
  classifyEnvironment,
  baseSweatRateFromCategory,
  sodiumConcentrationFromCategory,
  calculateActualSweatRate,
  replacementPctForDuration,
};

// ============================================================================
// DURING-WORKOUT NUTRITION
// ============================================================================

export function getDurationCarbBand(durationMin: number): [number, number] {
  if (durationMin < 60) return [0, 30];
  else if (durationMin < 90) return [30, 60];
  else if (durationMin < 150) return [45, 60];
  else if (durationMin < 240) return [60, 90];
  else return [80, 100];
}

export function getGutTrainingMultiplier(gutTraining: string): number {
  if (gutTraining === "low") return 0.7;
  if (gutTraining === "moderate") return 1.0;
  if (gutTraining === "high") return 1.2;
  return 1.0;
}

export function getSportCarbCeiling(activityType: string): number {
  if (activityType === "running") return 70;
  if (activityType === "cycling") return 120;
  if (activityType === "swimming") return 0;
  return 70;
}

export function calculateDuringWorkoutCarbRate(
  durationMin: number,
  activityType: string,
  gutTraining: string,
  _intensityDistribution: {
    zone_low: number;
    zone_mid: number;
    zone_high: number;
  },
): {
  rate_gph: number;
  band_low: number;
  band_high: number;
  raw_band_low: number;
  raw_band_high: number;
  gut_multiplier: number;
  sport_ceiling: number;
} {
  const [baseLow, baseHigh] = getDurationCarbBand(durationMin);
  const gutMult = getGutTrainingMultiplier(gutTraining);
  const scaledLow = baseLow * gutMult;
  const scaledHigh = baseHigh * gutMult;
  const carbRate = (scaledLow + scaledHigh) / 2;
  const sportCeiling = getSportCarbCeiling(activityType);
  const finalRate = Math.min(carbRate, sportCeiling);

  return {
    rate_gph: Math.round(finalRate * 10) / 10,
    band_low: Math.round(scaledLow),
    band_high: Math.round(scaledHigh),
    raw_band_low: baseLow,
    raw_band_high: baseHigh,
    gut_multiplier: gutMult,
    sport_ceiling: sportCeiling,
  };
}

// ============================================================================
// During-Workout Hydration Input Type
// ============================================================================

export interface DuringWorkoutHydrationInput {
  durationMin: number;
  weightKg: number;
  sweatRateCategory: string;
  sweatSodiumCat: string;
  tempC: number | null;
  humidityPct: number | null;
  isIndoor: boolean;
  sport: string; // 'running' | 'cycling' | 'swimming'
  knownSweatRateMlPerHour: number | null;
  knownSodiumConcMgPerL: number | null;
}

export interface DuringWorkoutHydrationResult {
  sodium_rate_mgph: number;
  hydration_rate_mlph: number;
  sodium_total_mg: number;
  hydration_total_ml: number;
  sweat_rate_lph: number;
  sodium_conc_mg_per_l: number;
  // New derivation fields
  effective_sweat_rate_lph: number;
  replacement_pct: number;
  floor_ml_hr: number;
  ceiling_ml_hr: number;
  safety_flags: string[];
  is_tested: boolean;
  is_tested_sodium: boolean;
  // Transparency breakdown (for step-numbered calc UI)
  base_sweat_rate_lph: number;
  temp_mult: number;
  humidity_mult: number;
  indoor_mult: number;
  replacement_band: string;
}

const GI_CEILING: Record<string, number> = {
  running: 800,
  cycling: 1200,
  swimming: 0, // cannot drink while swimming
};

function getDuringGiCeiling(sport: string): number {
  return GI_CEILING[sport.toLowerCase()] ?? 800;
}

/**
 * Calculate during-workout hydration targets.
 *
 * Implements spec algorithm:
 * - Duration-scaled replacement %
 * - Short-workout gate (duration < 60 && temp < 30)
 * - 2% BW floor
 * - GI ceiling (min(sport GI, 100% sweat rate))
 * - Sodium derived from fluid × concentration
 */
export function calculateDuringWorkoutHydration(
  input: DuringWorkoutHydrationInput,
): DuringWorkoutHydrationResult {
  const {
    durationMin,
    weightKg,
    sweatRateCategory,
    sweatSodiumCat,
    tempC,
    humidityPct,
    isIndoor,
    sport,
    knownSweatRateMlPerHour,
    knownSodiumConcMgPerL,
  } = input;

  const safety_flags: string[] = [];

  // Pre-compute the breakdown so we can expose temp/humidity/indoor mults.
  const breakdown = calculateSweatRateBreakdown(
    sweatRateCategory, tempC, humidityPct, isIndoor, knownSweatRateMlPerHour,
  );

  // Swim-only: no drinking possible
  if (sport.toLowerCase() === 'swimming') {
    const sodiumConc = knownSodiumConcMgPerL ?? sodiumConcentrationFromCategory(sweatSodiumCat);
    return {
      sodium_rate_mgph: 0,
      hydration_rate_mlph: 0,
      sodium_total_mg: 0,
      hydration_total_ml: 0,
      sweat_rate_lph: breakdown.effective_lph,
      sodium_conc_mg_per_l: sodiumConc,
      effective_sweat_rate_lph: breakdown.effective_lph,
      replacement_pct: 0,
      floor_ml_hr: 0,
      ceiling_ml_hr: 0,
      safety_flags: [],
      is_tested: knownSweatRateMlPerHour !== null,
      is_tested_sodium: knownSodiumConcMgPerL !== null,
      base_sweat_rate_lph: breakdown.base_lph,
      temp_mult: breakdown.temp_mult,
      humidity_mult: breakdown.humidity_mult,
      indoor_mult: breakdown.indoor_mult,
      replacement_band: replacementBandLabel(durationMin),
    };
  }

  const durationH = durationMin / 60;

  // Effective sweat rate
  const effectiveSweatRateLph = breakdown.effective_lph;
  const effectiveSweatRateMlph = effectiveSweatRateLph * 1000;

  // Sodium concentration
  const sodiumConcMgPerL = knownSodiumConcMgPerL ?? sodiumConcentrationFromCategory(sweatSodiumCat);

  // GI ceiling for this sport
  const giCeiling = getDuringGiCeiling(sport);
  // Ceiling = min(sport GI, 100% sweat rate)
  const ceilingMlHr = Math.round(Math.min(giCeiling, effectiveSweatRateMlph));

  // Replacement % by total duration
  const replacementPct = replacementPctForDuration(durationMin);

  // Short-workout gate: duration < 60 AND temp < 30
  const temp = tempC ?? 22;
  const gateTriggered = durationMin < 60 && temp < 30;

  if (gateTriggered) {
    // Conservative: still compute 30%-based recommended, floor = 0
    const recommended = Math.round(effectiveSweatRateMlph * replacementPct);
    safety_flags.push(
      'No structured hydration plan needed. Drink to thirst and hydrate before and immediately after.',
    );
    const sodiumRate = Math.round((recommended / 1000) * sodiumConcMgPerL);
    return {
      sodium_rate_mgph: sodiumRate,
      hydration_rate_mlph: recommended,
      sodium_total_mg: Math.round(sodiumRate * durationH),
      hydration_total_ml: Math.round(recommended * durationH),
      sweat_rate_lph: effectiveSweatRateLph,
      sodium_conc_mg_per_l: sodiumConcMgPerL,
      effective_sweat_rate_lph: effectiveSweatRateLph,
      replacement_pct: replacementPct,
      floor_ml_hr: 0,
      ceiling_ml_hr: ceilingMlHr,
      safety_flags,
      is_tested: knownSweatRateMlPerHour !== null,
      is_tested_sodium: knownSodiumConcMgPerL !== null,
      base_sweat_rate_lph: breakdown.base_lph,
      temp_mult: breakdown.temp_mult,
      humidity_mult: breakdown.humidity_mult,
      indoor_mult: breakdown.indoor_mult,
      replacement_band: replacementBandLabel(durationMin),
    };
  }

  // Standard path:
  // Total sweat loss over duration
  const totalLossMl = effectiveSweatRateMlph * durationH;

  // 2% BW floor
  const maxDeficitMl = weightKg * 1000 * 0.02;
  const rawFloorMlHr = (totalLossMl - maxDeficitMl) / durationH;
  const floorMlHr = Math.max(0, Math.round(rawFloorMlHr));

  // Pct-based recommendation
  const pctBasedMlHr = Math.round(effectiveSweatRateMlph * replacementPct);

  // Apply floor (raises target if needed)
  let recommendedMlHr = Math.max(pctBasedMlHr, floorMlHr);

  // Apply ceiling
  if (ceilingMlHr < floorMlHr) {
    // Ceiling < floor: impossible to stay within 2% BW
    safety_flags.push('Even at maximum intake, you will exceed 2% BW loss.');
  }

  recommendedMlHr = Math.min(recommendedMlHr, ceilingMlHr);

  // Safety check: realized deficit
  const totalIntakeMl = recommendedMlHr * durationH;
  const netDeficitMl = totalLossMl - totalIntakeMl;
  if (weightKg > 0) {
    const deficitPct = netDeficitMl / (weightKg * 1000);
    if (deficitPct > 0.03) {
      const deficitPctStr = (deficitPct * 100).toFixed(1);
      safety_flags.push(`Significant dehydration expected (>${deficitPctStr}% BW).`);
    }
  }

  const sodiumRateMgph = Math.round((recommendedMlHr / 1000) * sodiumConcMgPerL);

  return {
    sodium_rate_mgph: sodiumRateMgph,
    hydration_rate_mlph: recommendedMlHr,
    sodium_total_mg: Math.round(sodiumRateMgph * durationH),
    hydration_total_ml: Math.round(recommendedMlHr * durationH),
    sweat_rate_lph: effectiveSweatRateLph,
    sodium_conc_mg_per_l: sodiumConcMgPerL,
    effective_sweat_rate_lph: effectiveSweatRateLph,
    replacement_pct: replacementPct,
    floor_ml_hr: floorMlHr,
    ceiling_ml_hr: ceilingMlHr,
    safety_flags,
    is_tested: knownSweatRateMlPerHour !== null,
    is_tested_sodium: knownSodiumConcMgPerL !== null,
    base_sweat_rate_lph: breakdown.base_lph,
    temp_mult: breakdown.temp_mult,
    humidity_mult: breakdown.humidity_mult,
    indoor_mult: breakdown.indoor_mult,
    replacement_band: replacementBandLabel(durationMin),
  };
}

// ============================================================================
// POST-WORKOUT NUTRITION
// ============================================================================

export function calculatePostWorkoutCarbs(
  weightKg: number,
  durationH: number,
  isFasted: boolean,
): number {
  const durationMultiplier = durationH > 2 ? 1.2 : 1.0;
  const fastedMultiplier = isFasted ? 1.2 : 1.0;
  return Math.round(weightKg * durationMultiplier * fastedMultiplier);
}

export function calculatePostWorkoutProtein(
  weightKg: number,
  durationH: number,
  isFasted: boolean,
): number {
  let proteinPerKg: number;
  if (durationH <= 0.75) proteinPerKg = 0.25;
  else if (durationH <= 1.5) proteinPerKg = 0.30;
  else if (durationH <= 2.5) proteinPerKg = 0.35;
  else proteinPerKg = 0.40;
  if (isFasted) proteinPerKg += 0.05;
  return Math.min(40, Math.max(20, Math.round(weightKg * proteinPerKg)));
}

export function calculatePostWorkoutFat(weightKg: number): number {
  return Math.round(weightKg * 0.2);
}

export function calculatePostWorkoutHydration(
  durationH: number,
  actualSweatRateLph: number,
  sodiumConcMgPerL: number,
  duringHydrationMl: number,
): { sodium_mg: number; hydration_ml: number } {
  const totalSodiumLossMg = actualSweatRateLph * sodiumConcMgPerL * durationH;
  const duringSodiumMg = Math.round(
    actualSweatRateLph * sodiumConcMgPerL * 0.6 * durationH,
  );
  const sodiumDeficitMg = totalSodiumLossMg - duringSodiumMg;
  const postSodiumMg = Math.max(
    300,
    Math.min(700, Math.round(sodiumDeficitMg * 0.5)),
  );
  const totalHydrationLossMl = actualSweatRateLph * 1000 * durationH;
  const hydrationDeficitMl = totalHydrationLossMl - duringHydrationMl;
  const postHydrationMl = Math.round(Math.max(500, hydrationDeficitMl * 1.5));

  return { sodium_mg: postSodiumMg, hydration_ml: postHydrationMl };
}

// ============================================================================
// SPORT-SPECIFIC MET & ENERGY
// ============================================================================

export function runningMETFromPace(paceMinPerMile: number): number {
  const speedMph = 60.0 / paceMinPerMile;
  const speedMPerMin = speedMph * MPH_TO_M_PER_MIN;
  const vo2 = speedMph >= 4.0
    ? 0.2 * speedMPerMin + 3.5
    : 0.1 * speedMPerMin + 3.5;
  return vo2 / 3.5;
}

export function cyclingMETFromSpeed(speedKph: number, terrain: string): number {
  let met: number;
  if (speedKph <= 16) met = 6.0;
  else if (speedKph <= 19) met = 8.0;
  else if (speedKph <= 22) met = 10.0;
  else if (speedKph <= 25) met = 12.0;
  else if (speedKph <= 30) met = 14.0;
  else met = 16.0;
  if (terrain === "rolling") met *= 1.1;
  else if (terrain === "hilly") met *= 1.25;
  return met;
}

export function swimmingMETFromPace(
  pacePer100m: number,
  poolOrOpenWater: string,
  waterTempC: number,
): number {
  let met: number;
  if (pacePer100m >= 180) met = 6.0;
  else if (pacePer100m >= 150) met = 8.0;
  else if (pacePer100m >= 120) met = 10.0;
  else if (pacePer100m >= 90) met = 11.0;
  else met = 13.0;
  if (poolOrOpenWater === "open_water") met *= 1.15;
  if (waterTempC < 20) met *= 1.1;
  else if (waterTempC > 28) met *= 0.95;
  return met;
}

export function calculateGrossCalories(
  weightKg: number,
  durationMin: number,
  met: number,
): number {
  return Math.round(met * 3.5 * weightKg / 200.0 * durationMin);
}

export function calculateNetCalories(
  activityType: string,
  weightKg: number,
  distanceKm: number,
  speedKph?: number,
): number {
  if (activityType === "running") {
    return Math.round(1.0 * weightKg * distanceKm);
  } else if (activityType === "cycling") {
    const speed = speedKph ?? 25;
    let costPerKgKm: number;
    if (speed <= 20) costPerKgKm = 0.3;
    else if (speed <= 25) costPerKgKm = 0.35;
    else if (speed <= 30) costPerKgKm = 0.4;
    else costPerKgKm = 0.5;
    return Math.round(weightKg * distanceKm * costPerKgKm);
  } else if (activityType === "swimming") {
    return Math.round(3.5 * weightKg * distanceKm);
  }
  return Math.round(1.0 * weightKg * distanceKm);
}

// ============================================================================
// INTENSITY DISTRIBUTION HELPER
// ============================================================================

export function getIntensityDistribution(
  provided:
    | { zone_low?: number; zone_mid?: number; zone_high?: number }
    | undefined,
  met: number,
): { zone_low: number; zone_mid: number; zone_high: number } {
  if (
    provided && provided.zone_low !== undefined &&
    provided.zone_mid !== undefined && provided.zone_high !== undefined
  ) {
    const sum = provided.zone_low + provided.zone_mid + provided.zone_high;
    if (sum > 0) {
      return {
        zone_low: provided.zone_low / sum,
        zone_mid: provided.zone_mid / sum,
        zone_high: provided.zone_high / sum,
      };
    }
  }
  if (met < 7) return { zone_low: 0.8, zone_mid: 0.2, zone_high: 0.0 };
  else if (met < 9) return { zone_low: 0.3, zone_mid: 0.6, zone_high: 0.1 };
  else if (met < 11) return { zone_low: 0.1, zone_mid: 0.5, zone_high: 0.4 };
  else return { zone_low: 0.0, zone_mid: 0.3, zone_high: 0.7 };
}

// ============================================================================
// DATABASE QUERY
// ============================================================================

export async function loadPreWorkoutTemplates(
  // Optional client injection for unit tests — production path uses
  // createServiceClient() when no client is provided.
  // deno-lint-ignore no-explicit-any
  clientOverride?: any,
): Promise<{
  food: PreWorkoutTemplate[];
  drink: PreWorkoutTemplate[];
  electrolyte: PreWorkoutTemplate[];
}> {
  const supabase = clientOverride ?? createServiceClient();

  const [foodResult, drinkResult, electrolyteResult] = await Promise.all([
    supabase.from("pre_workout_templates").select("*").eq("is_active", true).eq(
      "template_type",
      "food",
    ),
    supabase.from("pre_workout_templates").select("*").eq("is_active", true).eq(
      "template_type",
      "drink",
    ),
    supabase.from("pre_workout_templates").select("*").eq("is_active", true).eq(
      "template_type",
      "electrolyte",
    ),
  ]);

  if (foodResult.error) {
    throw new Error(
      `Failed to load food templates: ${foodResult.error.message}`,
    );
  }
  if (drinkResult.error) {
    throw new Error(
      `Failed to load drink templates: ${drinkResult.error.message}`,
    );
  }
  if (electrolyteResult.error) {
    throw new Error(
      `Failed to load electrolyte templates: ${electrolyteResult.error.message}`,
    );
  }

  return {
    food: (foodResult.data ?? []) as PreWorkoutTemplate[],
    drink: (drinkResult.data ?? []) as PreWorkoutTemplate[],
    electrolyte: (electrolyteResult.data ?? []) as PreWorkoutTemplate[],
  };
}

// ============================================================================
// TYPES & INTERFACES
// ============================================================================

export interface NutritionOverrides {
  pre_carbs_g?: number;
  pre_protein_g?: number;
  pre_sodium_mg?: number;
  pre_water_ml?: number;
  during_carb_rate_g_per_h?: number;
  // Optional sport-specific carb rate overrides for brick segments.
  cycling_carb_rate_g_per_h?: number;
  running_carb_rate_g_per_h?: number;
  swimming_carb_rate_g_per_h?: number;
  // Legacy keys (`during_sodium_mg`, `during_water_ml`) are interpreted as
  // per-hour rates for backward compatibility with existing clients.
  during_sodium_mg?: number;
  during_water_ml?: number;
  during_sodium_rate_mg_per_h?: number;
  during_water_rate_ml_per_h?: number;
  post_carbs_g?: number;
  post_protein_g?: number;
  post_sodium_mg?: number;
  post_water_ml?: number;
}

export interface MacroInputV4 {
  weight: number;
  weight_unit: string;
  age?: number;
  gender?: string;
  hours_before: number;
  is_fasted: boolean;
  diet?: string;
  intensity_distribution?: {
    zone_low?: number;
    zone_mid?: number;
    zone_high?: number;
  };
  activity_type: string;
  run_distance?: number;
  run_distance_unit?: string;
  run_pace?: string | number;
  run_pace_unit?: string;
  distance_miles?: number;
  speed_mph?: number;
  terrain?: string;
  distance_meters?: number;
  pace_per_100m_seconds?: number;
  pool_or_open_water?: string;
  water_temp_c?: number;
  brick_segments?: Array<{
    sport: string;
    order: number;
    duration_minutes: number;
    intensity: string;
    override_carb_rate_g_per_h?: number;
    distance_meters?: number;
    pace_per_100m_seconds?: number;
    pool_or_open_water?: string;
    water_temp_c?: number;
    distance_miles?: number;
    speed_mph?: number;
    terrain?: string;
    indoor_outdoor?: string;
    elevation_gain_ft?: number;
    pace_minutes_per_mile?: number;
  }>;
  segment_order?: string[];
  gut_training: string;
  sweat_rate_category: string;
  sweat_sodium: string; // 'low' | 'average' | 'high' (or legacy 'medium' = alias for 'average')
  drink_sodium_mg_per_l?: number; // kept in schema but not consumed by new algorithm
  optional_sweat_rate_lph?: number; // legacy field, use known_sweat_rate_ml_hr instead
  temp_c?: number | null;
  humidity_pct?: number | null;
  is_indoor?: boolean; // new: indoor training flag (1.30× indoor multiplier)
  known_sweat_rate_ml_hr?: number | null; // new: known sweat rate from sweat test (ml/hr)
  known_sodium_concentration_mg_l?: number | null; // new: known sodium concentration from test (mg/L)
  overrides?: NutritionOverrides;
  liked_foods?: string[];
  disliked_foods?: string[];
  allergies?: string[];
  /**
   * Device identifier used to look up the user's active formula pins from
   * `formula_pins`. Optional — when absent, byte-identical pre-pin behavior
   * (no pin override). See `_shared/nutrition/pins.ts`. Formula Kit PR 2
   * substep 5b-followup (2026-05-22).
   */
  device_id?: string;
}

/**
 * Apply override: if an override value is provided, use it as the midpoint
 * and compute low/high around it using the given tolerance fractions.
 * Returns [value, low, high].
 */
export function applyOverride(
  calculated: number,
  calculatedLow: number,
  calculatedHigh: number,
  override: number | undefined,
  lowPct: number = 0.8,
  highPct: number = 1.2,
): [number, number, number] {
  if (override !== undefined && override > 0) {
    return [
      Math.round(override),
      Math.round(override * lowPct),
      Math.round(override * highPct),
    ];
  }
  return [calculated, calculatedLow, calculatedHigh];
}

// ============================================================================
// MAIN V4 CALCULATION (Single-Sport)
// ============================================================================

export async function calculateMacrosV4(
  input: MacroInputV4,
  templates: {
    food: PreWorkoutTemplate[];
    drink: PreWorkoutTemplate[];
    electrolyte: PreWorkoutTemplate[];
  },
  /**
   * Set of pre_workout_template ids the user has actively pinned. When
   * supplied + non-empty + a pin's `time_window` matches a sub-phase,
   * candidate selection is overridden for that phase (see substep 5a in
   * `pre-workout.ts`). Optional — empty/undefined yields byte-identical
   * pre-pin behavior.
   */
  beforePinIds?: Set<string>,
) {
  const weightKg = toKg(input.weight, input.weight_unit);
  const activityType = input.activity_type || "running";
  const diet = input.diet || "none";

  // Duration/MET/Distance calculations (same as V3)
  let durationMin: number;
  let durationH: number;
  let met: number;
  let distanceKm: number;
  let speedKph: number | undefined;

  if (activityType === "running") {
    const distanceMi = toMiles(
      input.run_distance!,
      input.run_distance_unit || "mi",
    );
    const paceMinPerMile = typeof input.run_pace === "string"
      ? parseFloat(input.run_pace.split(":")[0]) +
        parseFloat(input.run_pace.split(":")[1] || "0") / 60
      : input.run_pace!;
    durationMin = distanceMi * paceMinPerMile;
    durationH = durationMin / 60;
    met = runningMETFromPace(paceMinPerMile);
    distanceKm = distanceMi * MI_TO_KM;
    speedKph = (60 / paceMinPerMile) * MI_TO_KM;
  } else if (activityType === "cycling") {
    const distanceMi = input.distance_miles!;
    const speedMph = input.speed_mph!;
    durationMin = (distanceMi / speedMph) * 60;
    durationH = durationMin / 60;
    speedKph = speedMph * MI_TO_KM;
    met = cyclingMETFromSpeed(speedKph, input.terrain || "flat");
    distanceKm = distanceMi * MI_TO_KM;
  } else if (activityType === "swimming") {
    const distanceM = input.distance_meters!;
    const pacePer100m = input.pace_per_100m_seconds!;
    durationMin = (distanceM / 100) * pacePer100m / 60;
    durationH = durationMin / 60;
    met = swimmingMETFromPace(
      pacePer100m,
      input.pool_or_open_water || "pool",
      input.water_temp_c || 26,
    );
    distanceKm = distanceM / 1000;
  } else {
    throw new Error(`Unsupported activity type: ${activityType}`);
  }

  const intensityDist = getIntensityDistribution(
    input.intensity_distribution,
    met,
  );
  const [envMultiplier, envLabel] = classifyEnvironment(
    input.temp_c ?? null,
    input.humidity_pct ?? null,
  );

  // === PRE-WORKOUT (V4 — Algorithm C) ===
  const preTargetsLegacy = calculatePreWorkoutTargets(
    weightKg,
    input.hours_before,
    input.is_fasted,
    input.sweat_sodium ?? "average",
    envLabel,
  );

  // Spec-compliant pre-workout hydration (time-tier algorithm). Overlaid on
  // top of the legacy targets so carbs/protein/fat still drive food selection.
  // NOTE: applied regardless of is_fasted — fasted only affects carbs/protein/
  // fat, not fluid/sodium. The spec's pre-workout gate is duration < 60 AND
  // temp < 30, not fasted status.
  const preHydration = calculatePreWorkoutHydration({
    bodyWeightKg: weightKg,
    workoutDurationMin: durationMin,
    timeBeforeWorkoutMin: input.hours_before * 60,
    tempC: input.temp_c ?? null,
  });
  const preTargets = applyPreWorkoutHydrationOverlay(
    preTargetsLegacy,
    preHydration,
  );

  const preSelections = selectPreWorkoutFoods(
    preTargets,
    input.hours_before,
    diet,
    templates.food,
    templates.drink,
    templates.electrolyte,
    input.liked_foods ?? [],
    input.disliked_foods ?? [],
    input.allergies ?? [],
    beforePinIds,
  );

  // === DURING-WORKOUT (V3 unchanged) ===
  const duringCarbs = calculateDuringWorkoutCarbRate(
    durationMin,
    activityType,
    input.gut_training,
    intensityDist,
  );
  const duringHydration = calculateDuringWorkoutHydration({
    durationMin,
    weightKg,
    sweatRateCategory: input.sweat_rate_category ?? "medium",
    sweatSodiumCat: input.sweat_sodium ?? "average",
    tempC: input.temp_c ?? null,
    humidityPct: input.humidity_pct ?? null,
    isIndoor: input.is_indoor ?? false,
    sport: activityType,
    knownSweatRateMlPerHour: input.known_sweat_rate_ml_hr ?? null,
    knownSodiumConcMgPerL: input.known_sodium_concentration_mg_l ?? null,
  });
  const isSwimmingSession = activityType === "swimming";

  // === POST-WORKOUT (V3 unchanged) ===
  const postCarbs = calculatePostWorkoutCarbs(
    weightKg,
    durationH,
    input.is_fasted,
  );
  const postProtein = calculatePostWorkoutProtein(
    weightKg,
    durationH,
    input.is_fasted,
  );
  const postFat = calculatePostWorkoutFat(weightKg);
  const postHydration = calculatePostWorkoutHydration(
    durationH,
    duringHydration.sweat_rate_lph,
    duringHydration.sodium_conc_mg_per_l,
    duringHydration.hydration_total_ml,
  );

  // === ENERGY (V3 unchanged) ===
  const caloriesGross = calculateGrossCalories(weightKg, durationMin, met);
  const caloriesNet = calculateNetCalories(
    activityType,
    weightKg,
    distanceKm,
    speedKph,
  );

  // === APPLY OVERRIDES ===
  const ov = input.overrides;

  // Pre-workout overrides
  const [preCarbs, preCarbsLow, preCarbsHigh] = applyOverride(
    preTargets.carbs_g,
    preTargets.carbs_low_g,
    preTargets.carbs_high_g,
    ov?.pre_carbs_g,
  );
  const [preProtein, preProteinLow, preProteinHigh] = applyOverride(
    preTargets.protein_g,
    preTargets.protein_low_g,
    preTargets.protein_high_g,
    ov?.pre_protein_g,
  );
  const [preSodium, preSodiumLow, preSodiumHigh] = applyOverride(
    preTargets.sodium_mg,
    preTargets.sodium_low_mg,
    preTargets.sodium_high_mg,
    ov?.pre_sodium_mg,
  );
  const [preWater, preWaterLow, preWaterHigh] = applyOverride(
    preTargets.water_ml,
    preTargets.water_low_ml,
    preTargets.water_high_ml,
    ov?.pre_water_ml,
    0.85,
    1.15,
  );

  // During-workout overrides
  const duringSodiumRateOverride = ov?.during_sodium_rate_mg_per_h ??
    ov?.during_sodium_mg;
  const finalDuringSodiumRate = isSwimmingSession
    ? 0
    : (duringSodiumRateOverride !== undefined && duringSodiumRateOverride > 0
      ? duringSodiumRateOverride
      : duringHydration.sodium_rate_mgph);
  const durSodium = Math.round(finalDuringSodiumRate * durationH);
  const durSodiumLow = Math.round(durSodium * 0.8);
  const durSodiumHigh = Math.round(durSodium * 1.2);

  const duringWaterRateOverride = ov?.during_water_rate_ml_per_h ??
    ov?.during_water_ml;
  const finalDuringWaterRate = isSwimmingSession
    ? 0
    : (duringWaterRateOverride !== undefined && duringWaterRateOverride > 0
      ? duringWaterRateOverride
      : duringHydration.hydration_rate_mlph);
  const durWater = Math.round(finalDuringWaterRate * durationH);
  const durWaterLow = Math.round(durWater * 0.85);
  const durWaterHigh = Math.round(durWater * 1.15);
  const duringCarbRateOverride = ov?.during_carb_rate_g_per_h;
  const finalDuringCarbRate =
    duringCarbRateOverride !== undefined && duringCarbRateOverride > 0
      ? duringCarbRateOverride
      : duringCarbs.rate_gph;

  // Post-workout overrides
  const [postCarbsFinal, postCarbsLow, postCarbsHigh] = applyOverride(
    postCarbs,
    Math.round(postCarbs * 0.8),
    Math.round(postCarbs * 1.2),
    ov?.post_carbs_g,
  );
  const [postProteinFinal, postProteinLow, postProteinHigh] = applyOverride(
    postProtein,
    Math.round(postProtein * 0.8),
    Math.round(postProtein * 1.2),
    ov?.post_protein_g,
  );
  const [postSodium, postSodiumLow, postSodiumHigh] = applyOverride(
    postHydration.sodium_mg,
    Math.round(postHydration.sodium_mg * 0.7),
    Math.round(postHydration.sodium_mg * 1.3),
    ov?.post_sodium_mg,
    0.7,
    1.3,
  );
  const [postWater, postWaterLow, postWaterHigh] = applyOverride(
    postHydration.hydration_ml,
    Math.round(postHydration.hydration_ml * 0.8),
    Math.round(postHydration.hydration_ml * 1.2),
    ov?.post_water_ml,
  );

  return {
    algorithm_version: "v4",
    activity_type: activityType,

    // Duration & distance
    duration_min: Math.round(durationMin * 100) / 100,
    duration_h: Math.round(durationH * 10000) / 10000,
    distance_km: Math.round(distanceKm * 1000) / 1000,

    // Energy
    calories_gross_kcal: caloriesGross,
    calories_net_kcal: caloriesNet,
    MET: Math.round(met * 100) / 100,

    // Intensity
    intensity_distribution: intensityDist,

    // Pre-workout targets + ranges (with overrides applied)
    pre_run_carbs_g: preCarbs,
    pre_run_carbs_low_g: preCarbsLow,
    pre_run_carbs_high_g: preCarbsHigh,
    pre_run_protein_g: preProtein,
    pre_run_protein_low_g: preProteinLow,
    pre_run_protein_high_g: preProteinHigh,
    pre_run_fat_g: preTargets.fat_g,
    pre_run_sodium_mg: preSodium,
    pre_run_sodium_low_mg: preSodiumLow,
    pre_run_sodium_high_mg: preSodiumHigh,
    pre_run_water_ml: preWater,
    pre_run_water_low_ml: preWaterLow,
    pre_run_water_high_ml: preWaterHigh,
    pre_run_meal_type: preTargets.meal_type,

    // Pre-workout hydration transparency (spec time-tier algorithm)
    pre_run_hydration_tier: preHydration.tier,
    pre_run_hydration_gate_triggered: preHydration.gate_triggered,
    pre_run_hydration_message: preHydration.message,

    // Pre-workout food selections (V4 new)
    pre_run_selections: preSelections,

    // During-workout (with overrides applied)
    during_rate_g_per_h: finalDuringCarbRate,
    during_total_g: Math.round(finalDuringCarbRate * durationH),
    during_band_low_g_per_h: duringCarbs.band_low,
    during_band_high_g_per_h: duringCarbs.band_high,
    during_raw_band_low_g_per_h: duringCarbs.raw_band_low,
    during_raw_band_high_g_per_h: duringCarbs.raw_band_high,
    during_gut_multiplier: duringCarbs.gut_multiplier,
    during_sport_ceiling_g_per_h: duringCarbs.sport_ceiling,
    during_sodium_rate_mg_per_h: finalDuringSodiumRate,
    during_sodium_total_mg: durSodium,
    during_sodium_low_mg: durSodiumLow,
    during_sodium_high_mg: durSodiumHigh,
    during_water_rate_ml_per_h: finalDuringWaterRate,
    during_water_total_ml: durWater,
    during_water_low_ml: durWaterLow,
    during_water_high_ml: durWaterHigh,
    during_mass_norm_rate_g_per_h: weightKg > 0
      ? Math.round(finalDuringCarbRate / weightKg * 100) / 100
      : 0,
    during_abs_clamp_range_g_per_h: [
      duringCarbs.band_low,
      duringCarbs.band_high,
    ],

    // Post-workout (with overrides applied)
    post_run_carbs_g: postCarbsFinal,
    post_run_carbs_low_g: postCarbsLow,
    post_run_carbs_high_g: postCarbsHigh,
    post_run_protein_g: postProteinFinal,
    post_run_protein_low_g: postProteinLow,
    post_run_protein_high_g: postProteinHigh,
    post_run_fat_g: postFat,
    post_run_sodium_mg: postSodium,
    post_run_sodium_low_mg: postSodiumLow,
    post_run_sodium_high_mg: postSodiumHigh,
    post_run_water_ml: postWater,
    post_run_water_low_ml: postWaterLow,
    post_run_water_high_ml: postWaterHigh,

    // Hydration details (extended)
    sweat_rate_lph: duringHydration.sweat_rate_lph,
    sodium_conc_mg_per_l: duringHydration.sodium_conc_mg_per_l,
    environment_label: envLabel,
    environment_multiplier: envMultiplier,
    // Derivation transparency fields
    effective_sweat_rate_lph: duringHydration.effective_sweat_rate_lph,
    replacement_pct: duringHydration.replacement_pct,
    replacement_band: duringHydration.replacement_band,
    floor_ml_hr: duringHydration.floor_ml_hr,
    ceiling_ml_hr: duringHydration.ceiling_ml_hr,
    base_sweat_rate_lph: duringHydration.base_sweat_rate_lph,
    temp_mult: duringHydration.temp_mult,
    humidity_mult: duringHydration.humidity_mult,
    indoor_mult: duringHydration.indoor_mult,
    safety_flags: duringHydration.safety_flags,
    is_tested: duringHydration.is_tested,
    is_tested_sodium: duringHydration.is_tested_sodium,
    temp_c: input.temp_c ?? null,
    humidity_pct: input.humidity_pct ?? null,
    is_indoor: input.is_indoor ?? false,
  };
}
