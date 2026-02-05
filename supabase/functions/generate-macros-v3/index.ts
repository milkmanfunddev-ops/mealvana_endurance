/**
 * generate-macros-v3 Edge Function
 *
 * Rachel-corrected nutrition algorithm (v3) with research-validated formulas:
 * - Pre-workout: 1 g/kg per hour (linear, capped at 4 g/kg for 4h window)
 * - During-workout: Absolute g/hr bands based on duration (NOT body weight)
 * - Gut training: Multipliers (0.7×, 1.0×, 1.2×) applied to entire band
 * - Sport-specific ceilings: Running 70 g/hr, Cycling 120 g/hr, Swimming 0 g/hr
 * - During-workout target: Midpoint of the scaled band (no intensity positioning)
 * - Hydration/sodium: Baker 2017 sweat rate calculations with environmental adjustment
 *
 * References:
 * - ISSN Position Stand: Nutrient Timing (Kerksick et al. 2017)
 * - Jeukendrup A. (2014). "A Step Towards Personalized Sports Nutrition"
 * - docs/new_macros/new_notes_rachel.md
 * - docs/new_macros/new_notes_xuan.md
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, serverError, validationError } from '../_shared/responses.ts';

// ============================================================================
// UNIT CONVERSIONS
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
// ENVIRONMENT & HYDRATION (Baker 2017)
// ============================================================================

/**
 * Environment classification based on temperature and humidity
 * Returns multiplier for sweat rate adjustment
 */
function classifyEnvironment(tempC: number | null, humidityPct: number | null): [number, string] {
  if (tempC === null && humidityPct === null) {
    return [1.0, 'moderate'];
  }

  const t = tempC ?? 20.0;
  const h = humidityPct ?? 60.0;

  if (t <= 10) return [0.85, 'cool'];
  if (t <= 20 && h <= 60) return [1.0, 'temperate'];
  if (t <= 25 || (h > 60 && h <= 75)) return [1.1, 'warm'];
  if (t <= 30 || (h > 75 && h <= 85)) return [1.2, 'hot'];
  return [1.3, 'very_hot'];
}

/**
 * Sweat rate from category (Baker 2017 research values)
 */
function baseSweatRateFromCategory(category: string): number {
  if (category === 'light') return 0.75;
  if (category === 'medium') return 1.25;
  if (category === 'heavy') return 2.0;
  return 1.25; // default to medium
}

/**
 * Sodium concentration from sweat category (mg/L)
 */
function sodiumConcentrationFromCategory(category: string): number {
  if (category === 'low') return 550;
  if (category === 'medium') return 925;
  if (category === 'high') return 1150;
  return 925; // default to medium
}

/**
 * Calculate actual sweat rate with environmental adjustment
 */
function calculateActualSweatRate(
  baseCategory: string,
  tempC: number | null,
  humidityPct: number | null
): number {
  const baseRate = baseSweatRateFromCategory(baseCategory);
  const [envMultiplier] = classifyEnvironment(tempC, humidityPct);

  // Environmental adjustment: 1.0 + max(0, (temp - 20) * 0.04)
  let tempAdjustment = 1.0;
  if (tempC !== null && tempC > 20) {
    tempAdjustment = 1.0 + Math.max(0, (tempC - 20) * 0.04);
  }

  return baseRate * tempAdjustment;
}

// ============================================================================
// PRE-WORKOUT NUTRITION (V3 - Rachel Corrected)
// ============================================================================

/**
 * Pre-workout carbohydrate calculation (v3)
 * Linear: 1 g/kg per hour, capped at 4 g/kg for 4h window
 *
 * Key changes from v2:
 * - Removed intensity multipliers (intensity affects suggested window, not g/kg)
 * - Simplified to pure linear relationship
 * - Clear distinction between meal (≥2.5h), snack (1-2.5h), top-up (<1h)
 */
function calculatePreWorkoutMacros(
  weightKg: number,
  hoursBefore: number,
  isFasted: boolean,
  sweatSodiumCat: string,
  envLabel: string
): {
  carbs: number;
  protein: number;
  fat: number;
  sodium: number;
  hydration: number;
  meal_type: string;
} {
  // Fasted workouts = all zeros
  if (isFasted) {
    return {
      carbs: 0,
      protein: 0,
      fat: 0,
      sodium: 0,
      hydration: 0,
      meal_type: 'fasted',
    };
  }

  // Carbs: 1 g/kg per hour, capped at 4h
  const carbPerKg = Math.max(0.5, Math.min(hoursBefore, 4.0));
  const carbs = Math.round(weightKg * carbPerKg);

  // Meal type determines protein/fat/sodium/hydration
  let protein: number;
  let fat: number;
  let sodium: number;
  let hydration: number;
  let mealType: string;

  // Base sodium by sweat category
  const baseSodium = sweatSodiumCat === 'low' ? 300 : sweatSodiumCat === 'medium' ? 450 : 600;
  const envBump = (envLabel === 'hot' || envLabel === 'very_hot') ? 100 : 0;

  if (hoursBefore >= 2.5) {
    // Full meal (≥2.5 hours before)
    protein = Math.round(weightKg * 0.25);
    fat = Math.round(weightKg * 0.4);
    sodium = baseSodium + envBump;
    hydration = Math.round(weightKg * 6.5); // 6-7 ml/kg midpoint
    mealType = 'full_meal';
  } else if (hoursBefore >= 1.0) {
    // Snack (1-2.5 hours before)
    protein = Math.round(weightKg * 0.15);
    fat = 5;
    sodium = Math.round((baseSodium + envBump) * 0.5);
    hydration = Math.round(weightKg * 5.5); // 5-6 ml/kg midpoint
    mealType = 'snack';
  } else {
    // Top-up (<1 hour before)
    protein = 0;
    fat = 0;
    sodium = envBump + 100;
    hydration = 250; // 200-300ml fixed midpoint
    mealType = 'top_up';
  }

  return { carbs, protein, fat, sodium, hydration, meal_type: mealType };
}

// ============================================================================
// DURING-WORKOUT NUTRITION (V3 - Rachel Corrected)
// ============================================================================

/**
 * Duration-based carb bands (v3 Table 1)
 * Research-validated absolute ranges (NOT body-weight dependent)
 *
 * Source: Jeukendrup 2014, ISSN Position Stand
 */
function getDurationCarbBand(durationMin: number): [number, number] {
  if (durationMin < 60) {
    // <60 min: 0-30 g/hr (mouth rinse acceptable)
    return [0, 30];
  } else if (durationMin < 90) {
    // 60-90 min: 30-60 g/hr
    return [30, 60];
  } else if (durationMin < 150) {
    // 90 min - 2.5h: 45-60 g/hr
    return [45, 60];
  } else if (durationMin < 240) {
    // 2.5 - 4h: 60-90 g/hr
    return [60, 90];
  } else {
    // >4h: 80-100 g/hr
    return [80, 100];
  }
}

/**
 * Gut training multipliers (v3)
 * Applied to ENTIRE band, not as hard caps
 *
 * Research shows gut training improves tolerance and possibly absorption
 */
function getGutTrainingMultiplier(gutTraining: string): number {
  if (gutTraining === 'low') return 0.7;
  if (gutTraining === 'moderate') return 1.0;
  if (gutTraining === 'high') return 1.2;
  return 1.0; // default to moderate
}

/**
 * Sport-specific ceiling (applied AFTER gut training scaling)
 */
function getSportCarbCeiling(activityType: string): number {
  if (activityType === 'running') return 70;  // Running: limited by GI distress
  if (activityType === 'cycling') return 120; // Cycling: highest tolerance
  if (activityType === 'swimming') return 0;  // Swimming: cannot eat during activity
  return 70; // default to running
}

/**
 * Calculate during-workout carb rate (v3)
 *
 * Algorithm:
 * 1. Get duration band (absolute g/hr ranges)
 * 2. Apply gut training multiplier to entire band
 * 3. Take midpoint of scaled band
 * 4. Apply sport-specific ceiling
 */
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
  // Step 1: Get base duration band
  const [baseLow, baseHigh] = getDurationCarbBand(durationMin);

  // Step 2: Apply gut training multiplier to entire band
  const gutMult = getGutTrainingMultiplier(gutTraining);
  const scaledLow = baseLow * gutMult;
  const scaledHigh = baseHigh * gutMult;

  // Step 3: Use midpoint of scaled band (no intensity positioning)
  const carbRate = (scaledLow + scaledHigh) / 2;

  // Step 4: Apply sport-specific ceiling
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

/**
 * Calculate during-workout hydration and sodium (Baker 2017)
 */
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
  // Calculate actual sweat rate with environmental adjustment
  const actualSweatRateLph = calculateActualSweatRate(sweatRateCategory, tempC, humidityPct);

  // Sodium concentration from category
  const sodiumConcMgPerL = sodiumConcentrationFromCategory(sweatSodiumCat);

  // During-exercise sodium: 60% of sweat losses
  const sodiumRateMgph = Math.round(actualSweatRateLph * sodiumConcMgPerL * 0.6);

  // During-exercise hydration: 75% of sweat rate
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

/**
 * Post-workout carbohydrate calculation
 * Accounts for duration and fasted state
 */
function calculatePostWorkoutCarbs(
  weightKg: number,
  durationH: number,
  isFasted: boolean
): number {
  // Base rate: 1.0 g/kg for <2h, 1.2 g/kg for ≥2h
  const durationMultiplier = durationH > 2 ? 1.2 : 1.0;

  // Fasted multiplier: 20% boost if workout was fasted
  const fastedMultiplier = isFasted ? 1.2 : 1.0;

  return Math.round(weightKg * durationMultiplier * fastedMultiplier);
}

/**
 * Post-workout protein calculation
 * Slightly higher if fasted
 */
function calculatePostWorkoutProtein(
  weightKg: number,
  isFasted: boolean
): number {
  const proteinPerKg = isFasted ? 0.35 : 0.3;
  return Math.round(weightKg * proteinPerKg);
}

/**
 * Post-workout fat
 */
function calculatePostWorkoutFat(weightKg: number): number {
  return Math.round(weightKg * 0.2);
}

/**
 * Post-workout sodium and hydration
 * Based on deficit from during-exercise period
 */
function calculatePostWorkoutHydration(
  durationH: number,
  actualSweatRateLph: number,
  sodiumConcMgPerL: number,
  duringHydrationMl: number
): {
  sodium_mg: number;
  hydration_ml: number;
} {
  // Sodium deficit: total losses minus what was consumed during
  const totalSodiumLossMg = actualSweatRateLph * sodiumConcMgPerL * durationH;
  const duringSodiumMg = Math.round(actualSweatRateLph * sodiumConcMgPerL * 0.6 * durationH);
  const sodiumDeficitMg = totalSodiumLossMg - duringSodiumMg;

  // Replace 50% of sodium deficit, capped at 300-700 mg
  const postSodiumMg = Math.max(300, Math.min(700, Math.round(sodiumDeficitMg * 0.5)));

  // Hydration deficit: total losses minus what was consumed during
  const totalHydrationLossMl = actualSweatRateLph * 1000 * durationH;
  const hydrationDeficitMl = totalHydrationLossMl - duringHydrationMl;

  // Replace 150% of hydration deficit (minimum 500ml)
  const postHydrationMl = Math.round(Math.max(500, hydrationDeficitMl * 1.5));

  return {
    sodium_mg: postSodiumMg,
    hydration_ml: postHydrationMl,
  };
}

// ============================================================================
// SPORT-SPECIFIC MET & ENERGY CALCULATIONS
// ============================================================================

/**
 * Running MET from pace (ACSM formula with walk/run switch)
 */
function runningMETFromPace(paceMinPerMile: number): number {
  const speedMph = 60.0 / paceMinPerMile;
  const speedMPerMin = speedMph * MPH_TO_M_PER_MIN;

  // Walk/run switch at ~4.0 mph (15 min/mile)
  const vo2 = speedMph >= 4.0
    ? 0.2 * speedMPerMin + 3.5  // Running equation
    : 0.1 * speedMPerMin + 3.5; // Walking equation

  return vo2 / 3.5;
}

/**
 * Cycling MET from speed
 */
function cyclingMETFromSpeed(speedKph: number, terrain: string): number {
  let met: number;

  if (speedKph <= 16) met = 6.0;       // Leisure (~10 mph)
  else if (speedKph <= 19) met = 8.0;  // Light (~12 mph)
  else if (speedKph <= 22) met = 10.0; // Moderate (~14 mph)
  else if (speedKph <= 25) met = 12.0; // Vigorous (~16 mph)
  else if (speedKph <= 30) met = 14.0; // Very vigorous (~19 mph)
  else met = 16.0;                     // Racing (>19 mph)

  // Terrain adjustment
  if (terrain === 'rolling') met *= 1.1;
  else if (terrain === 'hilly') met *= 1.25;

  return met;
}

/**
 * Swimming MET from pace
 */
function swimmingMETFromPace(pacePer100m: number, poolOrOpenWater: string, waterTempC: number): number {
  let met: number;

  if (pacePer100m >= 180) met = 6.0;       // Very slow
  else if (pacePer100m >= 150) met = 8.0;  // Slow
  else if (pacePer100m >= 120) met = 10.0; // Moderate
  else if (pacePer100m >= 90) met = 11.0;  // Fast
  else met = 13.0;                         // Very fast

  // Open water adjustment
  if (poolOrOpenWater === 'open_water') met *= 1.15;

  // Water temperature adjustment
  if (waterTempC < 20) met *= 1.1;
  else if (waterTempC > 28) met *= 0.95;

  return met;
}

/**
 * Gross energy expenditure (ACSM formula, all sports)
 */
function calculateGrossCalories(weightKg: number, durationMin: number, met: number): number {
  return Math.round(met * 3.5 * weightKg / 200.0 * durationMin);
}

/**
 * Net energy expenditure (transport cost, sport-specific)
 */
function calculateNetCalories(
  activityType: string,
  weightKg: number,
  distanceKm: number,
  speedKph?: number
): number {
  if (activityType === 'running') {
    // Running: 1.0 kcal/kg/km
    return Math.round(1.0 * weightKg * distanceKm);
  } else if (activityType === 'cycling') {
    // Cycling: speed-dependent
    const speed = speedKph ?? 25;
    let costPerKgKm: number;
    if (speed <= 20) costPerKgKm = 0.3;
    else if (speed <= 25) costPerKgKm = 0.35;
    else if (speed <= 30) costPerKgKm = 0.4;
    else costPerKgKm = 0.5;
    return Math.round(weightKg * distanceKm * costPerKgKm);
  } else if (activityType === 'swimming') {
    // Swimming: 3.5 kcal/kg/km
    return Math.round(3.5 * weightKg * distanceKm);
  }

  // Default: simple estimate
  return Math.round(1.0 * weightKg * distanceKm);
}

// ============================================================================
// INTENSITY DISTRIBUTION HELPER
// ============================================================================

/**
 * Parse or generate intensity distribution
 * If not provided, estimate from MET value
 */
function getIntensityDistribution(
  provided: { zone_low?: number; zone_mid?: number; zone_high?: number } | undefined,
  met: number
): { zone_low: number; zone_mid: number; zone_high: number } {
  // If provided, validate and normalize
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

  // Otherwise, estimate from MET
  if (met < 7) {
    // Easy effort
    return { zone_low: 0.8, zone_mid: 0.2, zone_high: 0.0 };
  } else if (met < 9) {
    // Moderate effort
    return { zone_low: 0.3, zone_mid: 0.6, zone_high: 0.1 };
  } else if (met < 11) {
    // Hard effort
    return { zone_low: 0.1, zone_mid: 0.5, zone_high: 0.4 };
  } else {
    // Very hard / race effort
    return { zone_low: 0.0, zone_mid: 0.3, zone_high: 0.7 };
  }
}

// ============================================================================
// MAIN MACRO CALCULATION (V3)
// ============================================================================

interface BrickSegmentInput {
  sport: string;           // 'swimming' | 'cycling' | 'running'
  order: number;
  duration_minutes: number;
  intensity: string;       // 'easy' | 'moderate' | 'hard' | 'race'
  // Sport-specific optional fields
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

interface MacroInputV3 {
  // Biometrics
  weight: number;
  weight_unit: string;
  age?: number;
  gender?: string;

  // Timing
  hours_before: number;
  is_fasted: boolean;

  // Intensity (optional, will estimate from pace/speed if not provided)
  intensity_distribution?: {
    zone_low?: number;
    zone_mid?: number;
    zone_high?: number;
  };

  // Activity details (sport-specific fields)
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

  // Brick workout fields
  brick_segments?: BrickSegmentInput[];
  segment_order?: string[];

  // Personalization
  gut_training: string;
  sweat_rate_category: string;
  sweat_sodium: string;

  // Environment
  temp_c?: number | null;
  humidity_pct?: number | null;
}

function calculateMacrosV3(input: MacroInputV3) {
  const weightKg = toKg(input.weight, input.weight_unit);
  const activityType = input.activity_type || 'running';

  // Calculate duration and MET based on activity type
  let durationMin: number;
  let durationH: number;
  let met: number;
  let distanceKm: number;
  let speedKph: number | undefined;

  if (activityType === 'running') {
    // Running calculations
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
    // Cycling calculations
    const distanceMi = input.distance_miles!;
    const speedMph = input.speed_mph!;

    durationMin = (distanceMi / speedMph) * 60;
    durationH = durationMin / 60;
    speedKph = speedMph * MI_TO_KM;
    met = cyclingMETFromSpeed(speedKph, input.terrain || 'flat');
    distanceKm = distanceMi * MI_TO_KM;
  } else if (activityType === 'swimming') {
    // Swimming calculations
    const distanceM = input.distance_meters!;
    const pacePer100m = input.pace_per_100m_seconds!;

    durationMin = (distanceM / 100) * pacePer100m / 60;
    durationH = durationMin / 60;
    met = swimmingMETFromPace(
      pacePer100m,
      input.pool_or_open_water || 'pool',
      input.water_temp_c || 26
    );
    distanceKm = distanceM / 1000;
  } else {
    throw new Error(`Unsupported activity type: ${activityType}`);
  }

  // Get intensity distribution (provided or estimated)
  const intensityDist = getIntensityDistribution(input.intensity_distribution, met);

  // Environment classification
  const [envMultiplier, envLabel] = classifyEnvironment(input.temp_c ?? null, input.humidity_pct ?? null);

  // Pre-workout nutrition (v3)
  const preWorkout = calculatePreWorkoutMacros(
    weightKg,
    input.hours_before,
    input.is_fasted,
    input.sweat_sodium,
    envLabel
  );

  // During-workout carbs (v3)
  const duringCarbs = calculateDuringWorkoutCarbRate(
    durationMin,
    activityType,
    input.gut_training,
    intensityDist
  );

  // During-workout hydration (Baker 2017)
  const duringHydration = calculateDuringWorkoutHydration(
    durationH,
    input.sweat_rate_category,
    input.sweat_sodium,
    input.temp_c ?? null,
    input.humidity_pct ?? null
  );

  // Post-workout nutrition (v3)
  const postCarbs = calculatePostWorkoutCarbs(weightKg, durationH, input.is_fasted);
  const postProtein = calculatePostWorkoutProtein(weightKg, input.is_fasted);
  const postFat = calculatePostWorkoutFat(weightKg);

  const postHydration = calculatePostWorkoutHydration(
    durationH,
    duringHydration.sweat_rate_lph,
    duringHydration.sodium_conc_mg_per_l,
    duringHydration.hydration_total_ml
  );

  // Energy calculations
  const caloriesGross = calculateGrossCalories(weightKg, durationMin, met);
  const caloriesNet = calculateNetCalories(activityType, weightKg, distanceKm, speedKph);

  // Return normalized response format (compatible with v2 Dart parsing)
  return {
    algorithm_version: 'v3',
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

    // Pre-workout (normalized field names)
    pre_run_carbs_g: preWorkout.carbs,
    pre_run_protein_g: preWorkout.protein,
    pre_run_fat_g: preWorkout.fat,
    pre_run_sodium_mg: preWorkout.sodium,
    pre_run_water_ml: preWorkout.hydration,
    pre_run_meal_type: preWorkout.meal_type,

    // During-workout (normalized field names)
    during_rate_g_per_h: duringCarbs.rate_gph,
    during_total_g: Math.round(duringCarbs.rate_gph * durationH),
    during_band_low_g_per_h: duringCarbs.band_low,
    during_band_high_g_per_h: duringCarbs.band_high,
    during_gut_multiplier: duringCarbs.gut_multiplier,
    during_sport_ceiling_g_per_h: duringCarbs.sport_ceiling,
    during_sodium_rate_mg_per_h: duringHydration.sodium_rate_mgph,
    during_sodium_total_mg: duringHydration.sodium_total_mg,
    during_water_rate_ml_per_h: duringHydration.hydration_rate_mlph,
    during_water_total_ml: duringHydration.hydration_total_ml,

    // Post-workout (normalized field names)
    post_run_carbs_g: postCarbs,
    post_run_protein_g: postProtein,
    post_run_fat_g: postFat,
    post_run_sodium_mg: postHydration.sodium_mg,
    post_run_water_ml: postHydration.hydration_ml,

    // Hydration details
    sweat_rate_lph: duringHydration.sweat_rate_lph,
    sodium_conc_mg_per_l: duringHydration.sodium_conc_mg_per_l,
    environment_label: envLabel,
    environment_multiplier: envMultiplier,
  };
}

// ============================================================================
// BRICK WORKOUT CALCULATION (V3)
// ============================================================================

/**
 * Get MET value for a brick segment based on sport and parameters
 */
function getSegmentMET(segment: BrickSegmentInput): number {
  const sport = segment.sport;

  if (sport === 'swimming') {
    const pace = segment.pace_per_100m_seconds ?? 120;
    const poolOrOpen = segment.pool_or_open_water ?? 'pool';
    const waterTemp = segment.water_temp_c ?? 26;
    return swimmingMETFromPace(pace, poolOrOpen, waterTemp);
  } else if (sport === 'cycling') {
    const speedMph = segment.speed_mph ?? 18;
    const speedKph = speedMph * MI_TO_KM;
    const terrain = segment.terrain ?? 'flat';
    return cyclingMETFromSpeed(speedKph, terrain);
  } else if (sport === 'running') {
    const paceMinPerMile = segment.pace_minutes_per_mile ?? 9;
    return runningMETFromPace(paceMinPerMile);
  }

  // Default fallback
  return 8.0;
}

/**
 * Estimate intensity distribution from segment intensity label
 */
function intensityDistFromLabel(intensity: string): { zone_low: number; zone_mid: number; zone_high: number } {
  if (intensity === 'easy') return { zone_low: 0.8, zone_mid: 0.2, zone_high: 0.0 };
  if (intensity === 'moderate') return { zone_low: 0.3, zone_mid: 0.6, zone_high: 0.1 };
  if (intensity === 'hard') return { zone_low: 0.1, zone_mid: 0.5, zone_high: 0.4 };
  if (intensity === 'race') return { zone_low: 0.0, zone_mid: 0.3, zone_high: 0.7 };
  return { zone_low: 0.3, zone_mid: 0.6, zone_high: 0.1 }; // default moderate
}

/**
 * Calculate segment distance in km
 */
function getSegmentDistanceKm(segment: BrickSegmentInput): number {
  if (segment.sport === 'swimming') {
    return (segment.distance_meters ?? 0) / 1000;
  } else if (segment.sport === 'cycling') {
    return (segment.distance_miles ?? 0) * MI_TO_KM;
  } else if (segment.sport === 'running') {
    // Estimate from pace and duration if no direct distance
    if (segment.pace_minutes_per_mile && segment.duration_minutes) {
      const distMi = segment.duration_minutes / segment.pace_minutes_per_mile;
      return distMi * MI_TO_KM;
    }
    return 0;
  }
  return 0;
}

/**
 * Calculate segment distance in miles
 */
function getSegmentDistanceMiles(segment: BrickSegmentInput): number {
  if (segment.sport === 'swimming') {
    return (segment.distance_meters ?? 0) * 0.000621371;
  } else if (segment.sport === 'cycling') {
    return segment.distance_miles ?? 0;
  } else if (segment.sport === 'running') {
    if (segment.pace_minutes_per_mile && segment.duration_minutes) {
      return segment.duration_minutes / segment.pace_minutes_per_mile;
    }
    return 0;
  }
  return 0;
}

/**
 * Calculate brick workout macros using v3 formulas
 *
 * Design:
 * - Pre-workout: Reuse v3 calculatePreWorkoutMacros (supports hours_before, fasted)
 * - During per-segment: v3 carb rate + hydration per segment; swimming gets 0
 * - Transitions: Fixed values from v2 (T1: 20g carbs/200ml/150mg; T2: 25g/150ml/100mg)
 * - Post-workout: Reuse v3 post-workout functions (fasted boost, duration-aware)
 * - Energy: Sum per-segment MET-based gross/net calories
 */
function calculateBrickMacrosV3(input: MacroInputV3) {
  const weightKg = toKg(input.weight, input.weight_unit);
  const segments = input.brick_segments!;
  const isFasted = input.is_fasted;

  // Default sweat params since Dart client doesn't send these for brick
  const sweatRateCategory = input.sweat_rate_category || 'medium';
  const sweatSodiumCat = input.sweat_sodium || 'medium';
  const gutTraining = input.gut_training || 'moderate';

  // Environment
  const [_envMultiplier, envLabel] = classifyEnvironment(input.temp_c ?? null, input.humidity_pct ?? null);

  // ---- Totals ----
  const totalDurationMin = segments.reduce((sum, s) => sum + s.duration_minutes, 0);
  const totalDurationH = totalDurationMin / 60;

  // ---- Pre-workout (v3) ----
  const preWorkout = calculatePreWorkoutMacros(
    weightKg,
    input.hours_before,
    isFasted,
    sweatSodiumCat,
    envLabel
  );

  // ---- During: per-segment calculations ----
  const duringSegments: Array<{
    segment_order: number;
    sport: string;
    duration_minutes: number;
    carbs_g: number;
    protein_g: number;
    fat_g: number;
    sodium_mg: number;
    water_ml: number;
    food_categories: string[];
  }> = [];

  let totalGrossCalories = 0;
  let totalNetCalories = 0;
  let totalDistanceKm = 0;
  let totalDistanceMi = 0;

  for (const segment of segments) {
    const sport = segment.sport;
    const durationMin = segment.duration_minutes;
    const durationH = durationMin / 60;
    const met = getSegmentMET(segment);
    const intensityDist = input.intensity_distribution
      ? getIntensityDistribution(input.intensity_distribution, met)
      : intensityDistFromLabel(segment.intensity || 'moderate');

    // Energy
    const grossCal = calculateGrossCalories(weightKg, durationMin, met);
    const segDistKm = getSegmentDistanceKm(segment);
    const segDistMi = getSegmentDistanceMiles(segment);
    let speedKph: number | undefined;
    if (sport === 'cycling' && segment.speed_mph) {
      speedKph = segment.speed_mph * MI_TO_KM;
    }
    const netCal = calculateNetCalories(sport, weightKg, segDistKm, speedKph);

    totalGrossCalories += grossCal;
    totalNetCalories += netCal;
    totalDistanceKm += segDistKm;
    totalDistanceMi += segDistMi;

    // During-segment carbs & hydration
    if (sport === 'swimming') {
      // Swimming: cannot eat/drink during
      duringSegments.push({
        segment_order: segment.order,
        sport,
        duration_minutes: durationMin,
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 0,
        water_ml: 0,
        food_categories: ['during_swimming'],
      });
    } else {
      // Cycling or Running: use v3 carb rate and hydration
      const carbResult = calculateDuringWorkoutCarbRate(durationMin, sport, gutTraining, intensityDist);
      const hydrationResult = calculateDuringWorkoutHydration(
        durationH, sweatRateCategory, sweatSodiumCat,
        input.temp_c ?? null, input.humidity_pct ?? null
      );

      duringSegments.push({
        segment_order: segment.order,
        sport,
        duration_minutes: durationMin,
        carbs_g: Math.round(carbResult.rate_gph * durationH),
        protein_g: 0,
        fat_g: 0,
        sodium_mg: hydrationResult.sodium_total_mg,
        water_ml: hydrationResult.hydration_total_ml,
        food_categories: [`during_${sport}`],
      });
    }
  }

  // ---- Transitions (fixed values from v2) ----
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
    const transitionCarbs = i === 0 ? 20 : 25;
    const transitionSodium = i === 0 ? 150 : 100;
    const transitionWater = i === 0 ? 200 : 150;

    transitions.push({
      transition_name: transitionName,
      after_sport: segments[i].sport,
      before_sport: segments[i + 1].sport,
      carbs_g: transitionCarbs,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: transitionSodium,
      water_ml: transitionWater,
      timing_note: transitionName === 'T1'
        ? 'Within first 5-10 minutes after first segment'
        : 'Final 5-10 minutes of second segment',
      food_categories: ['transition'],
    });
  }

  // ---- Post-workout (v3) ----
  const postCarbs = calculatePostWorkoutCarbs(weightKg, totalDurationH, isFasted);
  const postProtein = calculatePostWorkoutProtein(weightKg, isFasted);

  // For post hydration, use aggregate sweat rate
  const actualSweatRateLph = calculateActualSweatRate(sweatRateCategory, input.temp_c ?? null, input.humidity_pct ?? null);
  const sodiumConcMgPerL = sodiumConcentrationFromCategory(sweatSodiumCat);

  // Sum during hydration for deficit calculation
  const totalDuringHydrationMl = duringSegments.reduce((sum, s) => sum + s.water_ml, 0)
    + transitions.reduce((sum, t) => sum + t.water_ml, 0);

  const postHydration = calculatePostWorkoutHydration(
    totalDurationH,
    actualSweatRateLph,
    sodiumConcMgPerL,
    totalDuringHydrationMl
  );

  // ---- Build response ----
  return {
    algorithm_version: 'v3',
    activity_type: 'brick',
    duration_h: Math.round(totalDurationH * 10000) / 10000,
    duration_min: Math.round(totalDurationMin * 100) / 100,
    distance_mi: Math.round(totalDistanceMi * 100) / 100,
    distance_km: Math.round(totalDistanceKm * 100) / 100,
    calories_gross_kcal: totalGrossCalories,
    calories_net_kcal: totalNetCalories,
    phases: {
      before: {
        carbs_g: preWorkout.carbs,
        protein_g: preWorkout.protein,
        fat_g: preWorkout.fat,
        sodium_mg: preWorkout.sodium,
        water_ml: preWorkout.hydration,
        meal_type: preWorkout.meal_type,
      },
      during_segments: duringSegments,
      transitions: transitions,
      after: {
        carbs_g: postCarbs,
        protein_g: postProtein,
        sodium_mg: postHydration.sodium_mg,
        water_ml: postHydration.hydration_ml,
      },
    },
  };
}

// ============================================================================
// EDGE FUNCTION HANDLER
// ============================================================================

serve(async (req: Request) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const input: MacroInputV3 = await req.json();

    // Validate required fields
    if (!input.weight) {
      return validationError('Missing required field: weight');
    }

    if (!input.hours_before && input.hours_before !== 0) {
      return validationError('Missing required field: hours_before');
    }

    if (input.is_fasted === undefined) {
      return validationError('Missing required field: is_fasted');
    }

    // Activity type validation
    const activityType = input.activity_type || 'running';

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
      // Validate brick-specific fields
      if (!input.brick_segments || !Array.isArray(input.brick_segments)) {
        return validationError('Missing required field for brick: brick_segments array');
      }
      if (input.brick_segments.length < 2 || input.brick_segments.length > 3) {
        return validationError('Brick workouts must have 2-3 segments');
      }
      // Validate each segment
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

    // Calculate macros (brick vs single-sport)
    if (activityType === 'brick') {
      const brickMacros = calculateBrickMacrosV3(input);

      console.log('✅ V3 brick macros calculated successfully:', {
        activity_type: brickMacros.activity_type,
        duration_h: brickMacros.duration_h,
        segments: brickMacros.phases.during_segments.length,
        transitions: brickMacros.phases.transitions.length,
      });

      return jsonResponse({
        success: true,
        macros: brickMacros,
      });
    }

    const macros = calculateMacrosV3(input);

    console.log('✅ V3 macros calculated successfully:', {
      activity_type: macros.activity_type,
      duration_h: macros.duration_h,
      pre_run_carbs_g: macros.pre_run_carbs_g,
      during_rate_g_per_h: macros.during_rate_g_per_h,
      during_total_g: macros.during_total_g,
      post_run_carbs_g: macros.post_run_carbs_g,
    });

    return jsonResponse({
      success: true,
      macros,
    });

  } catch (error) {
    console.error('❌ Error in generate-macros-v3:', error);
    return serverError(error);
  }
});
