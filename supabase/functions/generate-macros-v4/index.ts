/**
 * generate-macros-v4 Edge Function
 *
 * Algorithm C "Comfort-Capped Hybrid" — extends V3 with:
 * - Range-based targets for ALL pre-workout macros (carbs, protein, sodium, hydration)
 * - Food selection from pre_workout_templates database table
 * - Independent drink + electrolyte selection
 * - Per-phase food recommendations
 *
 * V3 calculations reused: during-workout, post-workout, energy, brick workouts
 *
 * References:
 * - ISSN Position Stand: Nutrient Timing (Kerksick et al. 2017)
 * - Jeukendrup A. (2014). "A Step Towards Personalized Sports Nutrition"
 * - Baker 2017 sweat rate calculations
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, serverError, validationError } from '../_shared/responses.ts';
import { createServiceClient } from '../_shared/supabase-client.ts';
import { calculatePreWorkoutTargets, selectPreWorkoutFoods } from './pre-workout.ts';
import type { PreWorkoutTemplate } from './types.ts';

// ============================================================================
// UNIT CONVERSIONS (from V3)
// ============================================================================

const LB_TO_KG = 0.45359237;
const IN_TO_CM = 2.54;
const MI_TO_KM = 1.60934;
const MPH_TO_M_PER_MIN = 26.8224;

function toKg(weight: number, unit: string): number {
  return unit === 'kg' ? weight : weight * LB_TO_KG;
}

function toCm(height: number, unit: string): number {
  return unit === 'cm' ? height : height * IN_TO_CM;
}

function toMiles(distance: number, unit: string): number {
  return unit === 'mi' ? distance : distance / MI_TO_KM;
}

// ============================================================================
// ENVIRONMENT & HYDRATION (Baker 2017 — from V3)
// ============================================================================

function classifyEnvironment(tempC: number | null, humidityPct: number | null): [number, string] {
  if (tempC === null && humidityPct === null) return [1.0, 'moderate'];
  const t = tempC ?? 20.0;
  const h = humidityPct ?? 60.0;
  if (t <= 10) return [0.85, 'cool'];
  if (t <= 20 && h <= 60) return [1.0, 'temperate'];
  if (t <= 25 || (h > 60 && h <= 75)) return [1.1, 'warm'];
  if (t <= 30 || (h > 75 && h <= 85)) return [1.2, 'hot'];
  return [1.3, 'very_hot'];
}

function baseSweatRateFromCategory(category: string): number {
  if (category === 'light') return 0.75;
  if (category === 'medium') return 1.25;
  if (category === 'heavy') return 2.0;
  return 1.25;
}

function sodiumConcentrationFromCategory(category: string): number {
  if (category === 'low') return 550;
  if (category === 'medium') return 925;
  if (category === 'high') return 1150;
  return 925;
}

function calculateActualSweatRate(
  baseCategory: string,
  tempC: number | null,
  _humidityPct: number | null
): number {
  const baseRate = baseSweatRateFromCategory(baseCategory);
  let tempAdjustment = 1.0;
  if (tempC !== null && tempC > 20) {
    tempAdjustment = 1.0 + Math.max(0, (tempC - 20) * 0.04);
  }
  return baseRate * tempAdjustment;
}

// ============================================================================
// DURING-WORKOUT NUTRITION (V3)
// ============================================================================

function getDurationCarbBand(durationMin: number): [number, number] {
  if (durationMin < 60) return [0, 30];
  else if (durationMin < 90) return [30, 60];
  else if (durationMin < 150) return [45, 60];
  else if (durationMin < 240) return [60, 90];
  else return [80, 100];
}

function getGutTrainingMultiplier(gutTraining: string): number {
  if (gutTraining === 'low') return 0.7;
  if (gutTraining === 'moderate') return 1.0;
  if (gutTraining === 'high') return 1.2;
  return 1.0;
}

function getSportCarbCeiling(activityType: string): number {
  if (activityType === 'running') return 70;
  if (activityType === 'cycling') return 120;
  if (activityType === 'swimming') return 0;
  return 70;
}

function calculateDuringWorkoutCarbRate(
  durationMin: number,
  activityType: string,
  gutTraining: string,
  _intensityDistribution: { zone_low: number; zone_mid: number; zone_high: number }
): {
  rate_gph: number;
  band_low: number;
  band_high: number;
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
    gut_multiplier: gutMult,
    sport_ceiling: sportCeiling,
  };
}

function calculateDuringWorkoutHydration(
  durationH: number,
  sweatRateCategory: string,
  sweatSodiumCat: string,
  tempC: number | null,
  humidityPct: number | null
): {
  sodium_rate_mgph: number;
  hydration_rate_mlph: number;
  sodium_total_mg: number;
  hydration_total_ml: number;
  sweat_rate_lph: number;
  sodium_conc_mg_per_l: number;
} {
  const actualSweatRateLph = calculateActualSweatRate(sweatRateCategory, tempC, humidityPct);
  const sodiumConcMgPerL = sodiumConcentrationFromCategory(sweatSodiumCat);
  const sodiumRateMgph = Math.round(actualSweatRateLph * sodiumConcMgPerL * 0.6);
  const hydrationRateMlph = Math.round(actualSweatRateLph * 1000 * 0.75);

  return {
    sodium_rate_mgph: sodiumRateMgph,
    hydration_rate_mlph: hydrationRateMlph,
    sodium_total_mg: Math.round(sodiumRateMgph * durationH),
    hydration_total_ml: Math.round(hydrationRateMlph * durationH),
    sweat_rate_lph: Math.round(actualSweatRateLph * 100) / 100,
    sodium_conc_mg_per_l: sodiumConcMgPerL,
  };
}

// ============================================================================
// POST-WORKOUT NUTRITION (V3)
// ============================================================================

function calculatePostWorkoutCarbs(weightKg: number, durationH: number, isFasted: boolean): number {
  const durationMultiplier = durationH > 2 ? 1.2 : 1.0;
  const fastedMultiplier = isFasted ? 1.2 : 1.0;
  return Math.round(weightKg * durationMultiplier * fastedMultiplier);
}

function calculatePostWorkoutProtein(weightKg: number, isFasted: boolean): number {
  const proteinPerKg = isFasted ? 0.35 : 0.3;
  return Math.round(weightKg * proteinPerKg);
}

function calculatePostWorkoutFat(weightKg: number): number {
  return Math.round(weightKg * 0.2);
}

function calculatePostWorkoutHydration(
  durationH: number,
  actualSweatRateLph: number,
  sodiumConcMgPerL: number,
  duringHydrationMl: number
): { sodium_mg: number; hydration_ml: number } {
  const totalSodiumLossMg = actualSweatRateLph * sodiumConcMgPerL * durationH;
  const duringSodiumMg = Math.round(actualSweatRateLph * sodiumConcMgPerL * 0.6 * durationH);
  const sodiumDeficitMg = totalSodiumLossMg - duringSodiumMg;
  const postSodiumMg = Math.max(300, Math.min(700, Math.round(sodiumDeficitMg * 0.5)));
  const totalHydrationLossMl = actualSweatRateLph * 1000 * durationH;
  const hydrationDeficitMl = totalHydrationLossMl - duringHydrationMl;
  const postHydrationMl = Math.round(Math.max(500, hydrationDeficitMl * 1.5));

  return { sodium_mg: postSodiumMg, hydration_ml: postHydrationMl };
}

// ============================================================================
// SPORT-SPECIFIC MET & ENERGY (V3)
// ============================================================================

function runningMETFromPace(paceMinPerMile: number): number {
  const speedMph = 60.0 / paceMinPerMile;
  const speedMPerMin = speedMph * MPH_TO_M_PER_MIN;
  const vo2 = speedMph >= 4.0
    ? 0.2 * speedMPerMin + 3.5
    : 0.1 * speedMPerMin + 3.5;
  return vo2 / 3.5;
}

function cyclingMETFromSpeed(speedKph: number, terrain: string): number {
  let met: number;
  if (speedKph <= 16) met = 6.0;
  else if (speedKph <= 19) met = 8.0;
  else if (speedKph <= 22) met = 10.0;
  else if (speedKph <= 25) met = 12.0;
  else if (speedKph <= 30) met = 14.0;
  else met = 16.0;
  if (terrain === 'rolling') met *= 1.1;
  else if (terrain === 'hilly') met *= 1.25;
  return met;
}

function swimmingMETFromPace(pacePer100m: number, poolOrOpenWater: string, waterTempC: number): number {
  let met: number;
  if (pacePer100m >= 180) met = 6.0;
  else if (pacePer100m >= 150) met = 8.0;
  else if (pacePer100m >= 120) met = 10.0;
  else if (pacePer100m >= 90) met = 11.0;
  else met = 13.0;
  if (poolOrOpenWater === 'open_water') met *= 1.15;
  if (waterTempC < 20) met *= 1.1;
  else if (waterTempC > 28) met *= 0.95;
  return met;
}

function calculateGrossCalories(weightKg: number, durationMin: number, met: number): number {
  return Math.round(met * 3.5 * weightKg / 200.0 * durationMin);
}

function calculateNetCalories(
  activityType: string,
  weightKg: number,
  distanceKm: number,
  speedKph?: number
): number {
  if (activityType === 'running') return Math.round(1.0 * weightKg * distanceKm);
  else if (activityType === 'cycling') {
    const speed = speedKph ?? 25;
    let costPerKgKm: number;
    if (speed <= 20) costPerKgKm = 0.3;
    else if (speed <= 25) costPerKgKm = 0.35;
    else if (speed <= 30) costPerKgKm = 0.4;
    else costPerKgKm = 0.5;
    return Math.round(weightKg * distanceKm * costPerKgKm);
  } else if (activityType === 'swimming') return Math.round(3.5 * weightKg * distanceKm);
  return Math.round(1.0 * weightKg * distanceKm);
}

// ============================================================================
// INTENSITY DISTRIBUTION HELPER (V3)
// ============================================================================

function getIntensityDistribution(
  provided: { zone_low?: number; zone_mid?: number; zone_high?: number } | undefined,
  met: number
): { zone_low: number; zone_mid: number; zone_high: number } {
  if (provided && provided.zone_low !== undefined && provided.zone_mid !== undefined && provided.zone_high !== undefined) {
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

async function loadPreWorkoutTemplates(): Promise<{
  food: PreWorkoutTemplate[];
  drink: PreWorkoutTemplate[];
  electrolyte: PreWorkoutTemplate[];
}> {
  const supabase = createServiceClient();

  const [foodResult, drinkResult, electrolyteResult] = await Promise.all([
    supabase.from('pre_workout_templates').select('*').eq('is_active', true).eq('template_type', 'food'),
    supabase.from('pre_workout_templates').select('*').eq('is_active', true).eq('template_type', 'drink'),
    supabase.from('pre_workout_templates').select('*').eq('is_active', true).eq('template_type', 'electrolyte'),
  ]);

  if (foodResult.error) throw new Error(`Failed to load food templates: ${foodResult.error.message}`);
  if (drinkResult.error) throw new Error(`Failed to load drink templates: ${drinkResult.error.message}`);
  if (electrolyteResult.error) throw new Error(`Failed to load electrolyte templates: ${electrolyteResult.error.message}`);

  return {
    food: (foodResult.data ?? []) as PreWorkoutTemplate[],
    drink: (drinkResult.data ?? []) as PreWorkoutTemplate[],
    electrolyte: (electrolyteResult.data ?? []) as PreWorkoutTemplate[],
  };
}

// ============================================================================
// MAIN V4 CALCULATION (Single-Sport)
// ============================================================================

interface NutritionOverrides {
  pre_carbs_g?: number;
  pre_protein_g?: number;
  pre_sodium_mg?: number;
  pre_water_ml?: number;
  during_carb_rate_g_per_h?: number;
  during_sodium_mg?: number;
  during_water_ml?: number;
  post_carbs_g?: number;
  post_protein_g?: number;
  post_sodium_mg?: number;
  post_water_ml?: number;
}

interface MacroInputV4 {
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
  brick_segments?: BrickSegmentInput[];
  segment_order?: string[];
  gut_training: string;
  sweat_rate_category: string;
  sweat_sodium: string;
  drink_sodium_mg_per_l?: number;
  optional_sweat_rate_lph?: number;
  temp_c?: number | null;
  humidity_pct?: number | null;
  overrides?: NutritionOverrides;
  liked_foods?: string[];
  disliked_foods?: string[];
}

interface BrickSegmentInput {
  sport: string;
  order: number;
  duration_minutes: number;
  intensity: string;
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
}

/**
 * Apply override: if an override value is provided, use it as the midpoint
 * and compute low/high around it using the given tolerance fractions.
 * Returns [value, low, high].
 */
function applyOverride(
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

async function calculateMacrosV4(
  input: MacroInputV4,
  templates: { food: PreWorkoutTemplate[]; drink: PreWorkoutTemplate[]; electrolyte: PreWorkoutTemplate[] },
) {
  const weightKg = toKg(input.weight, input.weight_unit);
  const activityType = input.activity_type || 'running';
  const diet = input.diet || 'none';

  // Duration/MET/Distance calculations (same as V3)
  let durationMin: number;
  let durationH: number;
  let met: number;
  let distanceKm: number;
  let speedKph: number | undefined;

  if (activityType === 'running') {
    const distanceMi = toMiles(input.run_distance!, input.run_distance_unit || 'mi');
    const paceMinPerMile = typeof input.run_pace === 'string'
      ? parseFloat(input.run_pace.split(':')[0]) + parseFloat(input.run_pace.split(':')[1] || '0') / 60
      : input.run_pace!;
    durationMin = distanceMi * paceMinPerMile;
    durationH = durationMin / 60;
    met = runningMETFromPace(paceMinPerMile);
    distanceKm = distanceMi * MI_TO_KM;
    speedKph = (60 / paceMinPerMile) * MI_TO_KM;
  } else if (activityType === 'cycling') {
    const distanceMi = input.distance_miles!;
    const speedMph = input.speed_mph!;
    durationMin = (distanceMi / speedMph) * 60;
    durationH = durationMin / 60;
    speedKph = speedMph * MI_TO_KM;
    met = cyclingMETFromSpeed(speedKph, input.terrain || 'flat');
    distanceKm = distanceMi * MI_TO_KM;
  } else if (activityType === 'swimming') {
    const distanceM = input.distance_meters!;
    const pacePer100m = input.pace_per_100m_seconds!;
    durationMin = (distanceM / 100) * pacePer100m / 60;
    durationH = durationMin / 60;
    met = swimmingMETFromPace(pacePer100m, input.pool_or_open_water || 'pool', input.water_temp_c || 26);
    distanceKm = distanceM / 1000;
  } else {
    throw new Error(`Unsupported activity type: ${activityType}`);
  }

  const intensityDist = getIntensityDistribution(input.intensity_distribution, met);
  const [envMultiplier, envLabel] = classifyEnvironment(input.temp_c ?? null, input.humidity_pct ?? null);

  // === PRE-WORKOUT (V4 — Algorithm C) ===
  const preTargets = calculatePreWorkoutTargets(
    weightKg,
    input.hours_before,
    input.is_fasted,
    input.sweat_sodium,
    envLabel,
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
  );

  // === DURING-WORKOUT (V3 unchanged) ===
  const duringCarbs = calculateDuringWorkoutCarbRate(durationMin, activityType, input.gut_training, intensityDist);
  const duringHydration = calculateDuringWorkoutHydration(
    durationH, input.sweat_rate_category, input.sweat_sodium,
    input.temp_c ?? null, input.humidity_pct ?? null
  );

  // === POST-WORKOUT (V3 unchanged) ===
  const postCarbs = calculatePostWorkoutCarbs(weightKg, durationH, input.is_fasted);
  const postProtein = calculatePostWorkoutProtein(weightKg, input.is_fasted);
  const postFat = calculatePostWorkoutFat(weightKg);
  const postHydration = calculatePostWorkoutHydration(
    durationH, duringHydration.sweat_rate_lph, duringHydration.sodium_conc_mg_per_l,
    duringHydration.hydration_total_ml
  );

  // === ENERGY (V3 unchanged) ===
  const caloriesGross = calculateGrossCalories(weightKg, durationMin, met);
  const caloriesNet = calculateNetCalories(activityType, weightKg, distanceKm, speedKph);

  // === APPLY OVERRIDES ===
  const ov = input.overrides;

  // Pre-workout overrides
  const [preCarbs, preCarbsLow, preCarbsHigh] = applyOverride(
    preTargets.carbs_g, preTargets.carbs_low_g, preTargets.carbs_high_g, ov?.pre_carbs_g);
  const [preProtein, preProteinLow, preProteinHigh] = applyOverride(
    preTargets.protein_g, preTargets.protein_low_g, preTargets.protein_high_g, ov?.pre_protein_g);
  const [preSodium, preSodiumLow, preSodiumHigh] = applyOverride(
    preTargets.sodium_mg, preTargets.sodium_low_mg, preTargets.sodium_high_mg, ov?.pre_sodium_mg);
  const [preWater, preWaterLow, preWaterHigh] = applyOverride(
    preTargets.water_ml, preTargets.water_low_ml, preTargets.water_high_ml, ov?.pre_water_ml, 0.85, 1.15);

  // During-workout overrides
  const duringSodiumCalc = duringHydration.sodium_total_mg;
  const [durSodium, durSodiumLow, durSodiumHigh] = applyOverride(
    duringSodiumCalc, Math.round(duringSodiumCalc * 0.8), Math.round(duringSodiumCalc * 1.2), ov?.during_sodium_mg);
  const duringWaterCalc = duringHydration.hydration_total_ml;
  const [durWater, durWaterLow, durWaterHigh] = applyOverride(
    duringWaterCalc, Math.round(duringWaterCalc * 0.85), Math.round(duringWaterCalc * 1.15), ov?.during_water_ml, 0.85, 1.15);
  const duringCarbRateOverride = ov?.during_carb_rate_g_per_h;
  const finalDuringCarbRate = duringCarbRateOverride !== undefined && duringCarbRateOverride > 0
    ? duringCarbRateOverride : duringCarbs.rate_gph;

  // Post-workout overrides
  const [postCarbsFinal, postCarbsLow, postCarbsHigh] = applyOverride(
    postCarbs, Math.round(postCarbs * 0.8), Math.round(postCarbs * 1.2), ov?.post_carbs_g);
  const [postProteinFinal, postProteinLow, postProteinHigh] = applyOverride(
    postProtein, Math.round(postProtein * 0.8), Math.round(postProtein * 1.2), ov?.post_protein_g);
  const [postSodium, postSodiumLow, postSodiumHigh] = applyOverride(
    postHydration.sodium_mg, Math.round(postHydration.sodium_mg * 0.7), Math.round(postHydration.sodium_mg * 1.3),
    ov?.post_sodium_mg, 0.7, 1.3);
  const [postWater, postWaterLow, postWaterHigh] = applyOverride(
    postHydration.hydration_ml, Math.round(postHydration.hydration_ml * 0.8), Math.round(postHydration.hydration_ml * 1.2),
    ov?.post_water_ml);

  return {
    algorithm_version: 'v4',
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

    // Pre-workout food selections (V4 new)
    pre_run_selections: preSelections,

    // During-workout (with overrides applied)
    during_rate_g_per_h: finalDuringCarbRate,
    during_total_g: Math.round(finalDuringCarbRate * durationH),
    during_band_low_g_per_h: duringCarbs.band_low,
    during_band_high_g_per_h: duringCarbs.band_high,
    during_gut_multiplier: duringCarbs.gut_multiplier,
    during_sport_ceiling_g_per_h: duringCarbs.sport_ceiling,
    during_sodium_rate_mg_per_h: duringHydration.sodium_rate_mgph,
    during_sodium_total_mg: durSodium,
    during_sodium_low_mg: durSodiumLow,
    during_sodium_high_mg: durSodiumHigh,
    during_water_rate_ml_per_h: duringHydration.hydration_rate_mlph,
    during_water_total_ml: durWater,
    during_water_low_ml: durWaterLow,
    during_water_high_ml: durWaterHigh,
    during_mass_norm_rate_g_per_h: weightKg > 0 ? Math.round(finalDuringCarbRate / weightKg * 100) / 100 : 0,
    during_abs_clamp_range_g_per_h: [duringCarbs.band_low, duringCarbs.band_high],

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

    // Hydration details
    sweat_rate_lph: duringHydration.sweat_rate_lph,
    sodium_conc_mg_per_l: duringHydration.sodium_conc_mg_per_l,
    environment_label: envLabel,
    environment_multiplier: envMultiplier,
  };
}

// ============================================================================
// BRICK WORKOUT CALCULATION (V4 — reuses V3 brick logic, adds V4 pre-workout)
// ============================================================================

function getSegmentMET(segment: BrickSegmentInput): number {
  if (segment.sport === 'swimming') {
    return swimmingMETFromPace(
      segment.pace_per_100m_seconds ?? 120,
      segment.pool_or_open_water ?? 'pool',
      segment.water_temp_c ?? 26
    );
  } else if (segment.sport === 'cycling') {
    return cyclingMETFromSpeed(
      (segment.speed_mph ?? 18) * MI_TO_KM,
      segment.terrain ?? 'flat'
    );
  } else if (segment.sport === 'running') {
    return runningMETFromPace(segment.pace_minutes_per_mile ?? 9);
  }
  return 8.0;
}

function intensityDistFromLabel(intensity: string): { zone_low: number; zone_mid: number; zone_high: number } {
  if (intensity === 'easy') return { zone_low: 0.8, zone_mid: 0.2, zone_high: 0.0 };
  if (intensity === 'moderate') return { zone_low: 0.3, zone_mid: 0.6, zone_high: 0.1 };
  if (intensity === 'hard') return { zone_low: 0.1, zone_mid: 0.5, zone_high: 0.4 };
  if (intensity === 'race') return { zone_low: 0.0, zone_mid: 0.3, zone_high: 0.7 };
  return { zone_low: 0.3, zone_mid: 0.6, zone_high: 0.1 };
}

function getSegmentDistanceKm(segment: BrickSegmentInput): number {
  if (segment.sport === 'swimming') return (segment.distance_meters ?? 0) / 1000;
  else if (segment.sport === 'cycling') return (segment.distance_miles ?? 0) * MI_TO_KM;
  else if (segment.sport === 'running') {
    if (segment.pace_minutes_per_mile && segment.duration_minutes) {
      return (segment.duration_minutes / segment.pace_minutes_per_mile) * MI_TO_KM;
    }
  }
  return 0;
}

function getSegmentDistanceMiles(segment: BrickSegmentInput): number {
  if (segment.sport === 'swimming') return (segment.distance_meters ?? 0) * 0.000621371;
  else if (segment.sport === 'cycling') return segment.distance_miles ?? 0;
  else if (segment.sport === 'running') {
    if (segment.pace_minutes_per_mile && segment.duration_minutes) {
      return segment.duration_minutes / segment.pace_minutes_per_mile;
    }
  }
  return 0;
}

function calculateBrickMacrosV4(
  input: MacroInputV4,
  preTargets: ReturnType<typeof calculatePreWorkoutTargets>,
) {
  const weightKg = toKg(input.weight, input.weight_unit);
  const segments = input.brick_segments!;
  const isFasted = input.is_fasted;
  const sweatRateCategory = input.sweat_rate_category || 'medium';
  const sweatSodiumCat = input.sweat_sodium || 'medium';
  const gutTraining = input.gut_training || 'moderate';
  const [_envMultiplier, envLabel] = classifyEnvironment(input.temp_c ?? null, input.humidity_pct ?? null);

  const totalDurationMin = segments.reduce((sum, s) => sum + s.duration_minutes, 0);
  const totalDurationH = totalDurationMin / 60;

  // During: per-segment calculations (same as V3 brick)
  const duringSegments: Array<{
    segment_order: number;
    sport: string;
    duration_minutes: number;
    carbs_g: number;
    protein_g: number;
    fat_g: number;
    sodium_mg: number;
    sodium_low_mg: number;
    sodium_high_mg: number;
    water_ml: number;
    water_low_ml: number;
    water_high_ml: number;
    food_categories: string[];
  }> = [];

  let totalGrossCalories = 0;
  let totalNetCalories = 0;
  let totalDistanceKm = 0;
  let totalDistanceMi = 0;

  for (let segIdx = 0; segIdx < segments.length; segIdx++) {
    const segment = segments[segIdx];
    const sport = segment.sport;
    const durationMin = segment.duration_minutes;
    const durationH = durationMin / 60;
    const met = getSegmentMET(segment);
    const intensityDist = input.intensity_distribution
      ? getIntensityDistribution(input.intensity_distribution, met)
      : intensityDistFromLabel(segment.intensity || 'moderate');

    const prevSport = segIdx > 0 ? segments[segIdx - 1].sport : null;
    const brickPenalty = (sport === 'running' && prevSport === 'cycling') ? 0.80 : 1.0;

    const grossCal = calculateGrossCalories(weightKg, durationMin, met);
    const segDistKm = getSegmentDistanceKm(segment);
    const segDistMi = getSegmentDistanceMiles(segment);
    let speedKph: number | undefined;
    if (sport === 'cycling' && segment.speed_mph) speedKph = segment.speed_mph * MI_TO_KM;
    const netCal = calculateNetCalories(sport, weightKg, segDistKm, speedKph);

    totalGrossCalories += grossCal;
    totalNetCalories += netCal;
    totalDistanceKm += segDistKm;
    totalDistanceMi += segDistMi;

    if (sport === 'swimming') {
      duringSegments.push({
        segment_order: segment.order,
        sport, duration_minutes: durationMin,
        carbs_g: 0, protein_g: 0, fat_g: 0,
        sodium_mg: 0, sodium_low_mg: 0, sodium_high_mg: 0,
        water_ml: 0, water_low_ml: 0, water_high_ml: 0,
        food_categories: ['during_swimming'],
      });
    } else {
      const carbResult = calculateDuringWorkoutCarbRate(durationMin, sport, gutTraining, intensityDist);
      const hydrationResult = calculateDuringWorkoutHydration(
        durationH, sweatRateCategory, sweatSodiumCat,
        input.temp_c ?? null, input.humidity_pct ?? null
      );
      const adjustedCarbRate = carbResult.rate_gph * brickPenalty;

      duringSegments.push({
        segment_order: segment.order,
        sport, duration_minutes: durationMin,
        carbs_g: Math.round(adjustedCarbRate * durationH),
        protein_g: 0, fat_g: 0,
        sodium_mg: hydrationResult.sodium_total_mg,
        sodium_low_mg: Math.round(hydrationResult.sodium_total_mg * 0.8),
        sodium_high_mg: Math.round(hydrationResult.sodium_total_mg * 1.2),
        water_ml: hydrationResult.hydration_total_ml,
        water_low_ml: Math.round(hydrationResult.hydration_total_ml * 0.85),
        water_high_ml: Math.round(hydrationResult.hydration_total_ml * 1.15),
        food_categories: [`during_${sport}`],
      });
    }
  }

  // Transitions (same as V3)
  const transitions: Array<{
    transition_name: string;
    after_sport: string;
    before_sport: string;
    carbs_g: number;
    protein_g: number;
    fat_g: number;
    sodium_mg: number;
    water_ml: number;
    timing_note: string;
    food_categories: string[];
  }> = [];

  for (let i = 0; i < segments.length - 1; i++) {
    const transitionName = i === 0 ? 'T1' : 'T2';
    let transitionCarbs: number, transitionSodium: number, transitionWater: number;
    if (totalDurationMin < 90) {
      transitionCarbs = 0; transitionSodium = 0; transitionWater = 0;
    } else if (totalDurationMin < 180) {
      transitionCarbs = 0; transitionSodium = 0; transitionWater = 50;
    } else {
      const carbsPerKg = i === 0 ? 0.3 : 0.35;
      transitionCarbs = Math.round(weightKg * carbsPerKg);
      if (totalDurationMin < 420) {
        if (i === 0) { transitionSodium = 150; transitionWater = 150; }
        else { transitionSodium = 100; transitionWater = 100; }
      } else {
        if (i === 0) { transitionSodium = 200; transitionWater = 200; }
        else { transitionSodium = 150; transitionWater = 150; }
      }
    }

    transitions.push({
      transition_name: transitionName,
      after_sport: segments[i].sport,
      before_sport: segments[i + 1].sport,
      carbs_g: transitionCarbs, protein_g: 0, fat_g: 0,
      sodium_mg: transitionSodium, water_ml: transitionWater,
      timing_note: transitionName === 'T1'
        ? 'Within first 5-10 minutes after first segment'
        : 'Final 5-10 minutes of second segment',
      food_categories: ['transition'],
    });
  }

  // Post-workout (same as V3)
  const postCarbs = calculatePostWorkoutCarbs(weightKg, totalDurationH, isFasted);
  const postProtein = calculatePostWorkoutProtein(weightKg, isFasted);
  const actualSweatRateLph = calculateActualSweatRate(sweatRateCategory, input.temp_c ?? null, input.humidity_pct ?? null);
  const sodiumConcMgPerL = sodiumConcentrationFromCategory(sweatSodiumCat);
  const totalDuringHydrationMl = duringSegments.reduce((sum, s) => sum + s.water_ml, 0)
    + transitions.reduce((sum, t) => sum + t.water_ml, 0);
  const postHydration = calculatePostWorkoutHydration(
    totalDurationH, actualSweatRateLph, sodiumConcMgPerL, totalDuringHydrationMl
  );

  return {
    algorithm_version: 'v4',
    activity_type: 'brick',
    duration_h: Math.round(totalDurationH * 10000) / 10000,
    duration_min: Math.round(totalDurationMin * 100) / 100,
    distance_mi: Math.round(totalDistanceMi * 100) / 100,
    distance_km: Math.round(totalDistanceKm * 100) / 100,
    calories_gross_kcal: totalGrossCalories,
    calories_net_kcal: totalNetCalories,
    phases: {
      before: {
        carbs_g: preTargets.carbs_g,
        protein_g: preTargets.protein_g,
        fat_g: preTargets.fat_g,
        sodium_mg: preTargets.sodium_mg,
        water_ml: preTargets.water_ml,
        meal_type: preTargets.meal_type,
        // V4 range fields
        carbs_low_g: preTargets.carbs_low_g,
        carbs_high_g: preTargets.carbs_high_g,
        protein_low_g: preTargets.protein_low_g,
        protein_high_g: preTargets.protein_high_g,
        sodium_low_mg: preTargets.sodium_low_mg,
        sodium_high_mg: preTargets.sodium_high_mg,
        water_low_ml: preTargets.water_low_ml,
        water_high_ml: preTargets.water_high_ml,
      },
      during_segments: duringSegments,
      transitions: transitions,
      after: {
        carbs_g: postCarbs,
        carbs_low_g: Math.round(postCarbs * 0.8),
        carbs_high_g: Math.round(postCarbs * 1.2),
        protein_g: postProtein,
        protein_low_g: Math.round(postProtein * 0.8),
        protein_high_g: Math.round(postProtein * 1.2),
        sodium_mg: postHydration.sodium_mg,
        sodium_low_mg: Math.round(postHydration.sodium_mg * 0.7),
        sodium_high_mg: Math.round(postHydration.sodium_mg * 1.3),
        water_ml: postHydration.hydration_ml,
        water_low_ml: Math.round(postHydration.hydration_ml * 0.8),
        water_high_ml: Math.round(postHydration.hydration_ml * 1.2),
      },
    },
  };
}

// ============================================================================
// EDGE FUNCTION HANDLER
// ============================================================================

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const input: MacroInputV4 = await req.json();

    // Validate required fields
    if (!input.weight) return validationError('Missing required field: weight');
    if (!input.hours_before && input.hours_before !== 0) return validationError('Missing required field: hours_before');
    if (input.is_fasted === undefined) return validationError('Missing required field: is_fasted');

    const activityType = input.activity_type || 'running';

    // Activity-specific validation (same as V3)
    if (activityType === 'running') {
      if (!input.run_distance || !input.run_pace) {
        return validationError('Missing required fields for running: run_distance and run_pace');
      }
    } else if (activityType === 'cycling') {
      if (!input.distance_miles || !input.speed_mph) {
        return validationError('Missing required fields for cycling: distance_miles and speed_mph');
      }
    } else if (activityType === 'swimming') {
      if (!input.distance_meters || !input.pace_per_100m_seconds) {
        return validationError('Missing required fields for swimming: distance_meters and pace_per_100m_seconds');
      }
    } else if (activityType === 'brick') {
      if (!input.brick_segments || !Array.isArray(input.brick_segments)) {
        return validationError('Missing required field for brick: brick_segments array');
      }
      if (input.brick_segments.length < 2 || input.brick_segments.length > 3) {
        return validationError('Brick workouts must have 2-3 segments');
      }
      for (let i = 0; i < input.brick_segments.length; i++) {
        const seg = input.brick_segments[i];
        if (!seg.sport || seg.duration_minutes === undefined || seg.duration_minutes === null || seg.duration_minutes <= 0) {
          return validationError(`Brick segment ${i} missing required fields: sport and duration_minutes (must be > 0)`);
        }
        const validSports = ['swimming', 'cycling', 'running'];
        if (!validSports.includes(seg.sport)) {
          return validationError(`Brick segment ${i} has invalid sport: ${seg.sport}. Must be swimming, cycling, or running.`);
        }
      }
    } else {
      return errorResponse(`Invalid activity_type: ${activityType}. Must be running, cycling, swimming, or brick.`);
    }

    // Load pre-workout templates from database
    const templates = await loadPreWorkoutTemplates();
    console.log(`📦 Loaded templates: ${templates.food.length} food, ${templates.drink.length} drink, ${templates.electrolyte.length} electrolyte`);

    // Calculate macros
    if (activityType === 'brick') {
      const weightKg = toKg(input.weight, input.weight_unit);
      const [_envMultiplier, envLabel] = classifyEnvironment(input.temp_c ?? null, input.humidity_pct ?? null);

      const preTargets = calculatePreWorkoutTargets(
        weightKg, input.hours_before, input.is_fasted,
        input.sweat_sodium, envLabel,
      );

      const brickMacros = calculateBrickMacrosV4(input, preTargets);

      console.log('✅ V4 brick macros calculated successfully:', {
        activity_type: brickMacros.activity_type,
        duration_h: brickMacros.duration_h,
        segments: brickMacros.phases.during_segments.length,
        transitions: brickMacros.phases.transitions.length,
      });

      return jsonResponse({ success: true, macros: brickMacros });
    }

    const macros = await calculateMacrosV4(input, templates);

    console.log('✅ V4 macros calculated successfully:', {
      activity_type: macros.activity_type,
      duration_h: macros.duration_h,
      pre_run_carbs_g: macros.pre_run_carbs_g,
      pre_run_selections: macros.pre_run_selections.length,
      during_rate_g_per_h: macros.during_rate_g_per_h,
      during_total_g: macros.during_total_g,
      post_run_carbs_g: macros.post_run_carbs_g,
    });

    return jsonResponse({ success: true, macros });

  } catch (error) {
    console.error('❌ Error in generate-macros-v4:', error);
    return serverError(error);
  }
});
