/**
 * Brick workout macro calculation logic for generate-macros-v4.
 *
 * Handles multi-segment workouts (swim → bike → run).
 * Includes transition nutrition and per-segment calculations.
 */

import {
  MI_TO_KM,
  toKg,
  classifyEnvironment,
  calculateActualSweatRate,
  sodiumConcentrationFromCategory,
  runningMETFromPace,
  cyclingMETFromSpeed,
  swimmingMETFromPace,
  calculateGrossCalories,
  calculateNetCalories,
  calculateDuringWorkoutCarbRate,
  calculateDuringWorkoutHydration,
  calculatePostWorkoutCarbs,
  calculatePostWorkoutProtein,
  calculatePostWorkoutHydration,
  getIntensityDistribution,
  type MacroInputV4,
  type NutritionOverrides,
} from "./single-sport.ts";
import { calculatePreWorkoutTargets } from "./pre-workout.ts";

// ============================================================================
// BRICK SEGMENT TYPES
// ============================================================================

export interface BrickSegmentInput {
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
}

// ============================================================================
// BRICK SEGMENT CALCULATIONS
// ============================================================================

function getSegmentMET(segment: BrickSegmentInput): number {
  if (segment.sport === "swimming") {
    return swimmingMETFromPace(
      segment.pace_per_100m_seconds ?? 120,
      segment.pool_or_open_water ?? "pool",
      segment.water_temp_c ?? 26,
    );
  } else if (segment.sport === "cycling") {
    return cyclingMETFromSpeed(
      (segment.speed_mph ?? 18) * MI_TO_KM,
      segment.terrain ?? "flat",
    );
  } else if (segment.sport === "running") {
    return runningMETFromPace(segment.pace_minutes_per_mile ?? 9);
  }
  return 8.0;
}

function intensityDistFromLabel(
  intensity: string,
): { zone_low: number; zone_mid: number; zone_high: number } {
  if (intensity === "easy") {
    return { zone_low: 0.8, zone_mid: 0.2, zone_high: 0.0 };
  }
  if (intensity === "moderate") {
    return { zone_low: 0.3, zone_mid: 0.6, zone_high: 0.1 };
  }
  if (intensity === "hard") {
    return { zone_low: 0.1, zone_mid: 0.5, zone_high: 0.4 };
  }
  if (intensity === "race") {
    return { zone_low: 0.0, zone_mid: 0.3, zone_high: 0.7 };
  }
  return { zone_low: 0.3, zone_mid: 0.6, zone_high: 0.1 };
}

function getSegmentDistanceKm(segment: BrickSegmentInput): number {
  if (segment.sport === "swimming") {
    return (segment.distance_meters ?? 0) / 1000;
  } else if (segment.sport === "cycling") {
    return (segment.distance_miles ?? 0) * MI_TO_KM;
  } else if (segment.sport === "running") {
    if (segment.pace_minutes_per_mile && segment.duration_minutes) {
      return (segment.duration_minutes / segment.pace_minutes_per_mile) *
        MI_TO_KM;
    }
  }
  return 0;
}

function getSegmentDistanceMiles(segment: BrickSegmentInput): number {
  if (segment.sport === "swimming") {
    return (segment.distance_meters ?? 0) * 0.000621371;
  } else if (segment.sport === "cycling") return segment.distance_miles ?? 0;
  else if (segment.sport === "running") {
    if (segment.pace_minutes_per_mile && segment.duration_minutes) {
      return segment.duration_minutes / segment.pace_minutes_per_mile;
    }
  }
  return 0;
}

function resolveBrickSegmentCarbRateOverride(
  segment: BrickSegmentInput,
  overrides?: NutritionOverrides,
): number | undefined {
  if (
    segment.override_carb_rate_g_per_h !== undefined &&
    segment.override_carb_rate_g_per_h > 0
  ) {
    return segment.override_carb_rate_g_per_h;
  }

  if (!overrides) return undefined;

  const sportSpecificKey = `${segment.sport}_carb_rate_g_per_h` as keyof NutritionOverrides;
  const sportSpecificValue = overrides[sportSpecificKey];
  if (typeof sportSpecificValue === "number" && sportSpecificValue > 0) {
    return sportSpecificValue;
  }

  if (
    overrides.during_carb_rate_g_per_h !== undefined &&
    overrides.during_carb_rate_g_per_h > 0
  ) {
    return overrides.during_carb_rate_g_per_h;
  }

  return undefined;
}

// ============================================================================
// MAIN BRICK CALCULATION
// ============================================================================

export function calculateBrickMacrosV4(
  input: MacroInputV4,
  preTargets: ReturnType<typeof calculatePreWorkoutTargets>,
) {
  const weightKg = toKg(input.weight, input.weight_unit);
  const segments = input.brick_segments!;
  const isFasted = input.is_fasted;
  const sweatRateCategory = input.sweat_rate_category || "medium";
  const sweatSodiumCat = input.sweat_sodium || "medium";
  const gutTraining = input.gut_training || "moderate";
  const ov = input.overrides;
  const [_envMultiplier, envLabel] = classifyEnvironment(
    input.temp_c ?? null,
    input.humidity_pct ?? null,
  );

  const totalDurationMin = segments.reduce(
    (sum, s) => sum + s.duration_minutes,
    0,
  );
  const totalDurationH = totalDurationMin / 60;

  // During: per-segment calculations (same as V3 brick)
  const duringSegments: Array<{
    segment_order: number;
    sport: string;
    duration_minutes: number;
    carbs_g: number;
    carbs_low_g: number;
    carbs_high_g: number;
    carbs_rate_g_per_h: number;
    protein_g: number;
    fat_g: number;
    sodium_mg: number;
    sodium_low_mg: number;
    sodium_high_mg: number;
    water_ml: number;
    water_low_ml: number;
    water_high_ml: number;
    food_categories: string[];
    // Transparency fields
    raw_band_low_g_per_h: number;
    raw_band_high_g_per_h: number;
    scaled_band_low_g_per_h: number;
    scaled_band_high_g_per_h: number;
    gut_multiplier: number;
    sport_ceiling_g_per_h: number;
    brick_penalty: number;
    cumulative_duration_min: number;
  }> = [];

  let totalGrossCalories = 0;
  let totalNetCalories = 0;
  let totalDistanceKm = 0;
  let totalDistanceMi = 0;
  let cumulativeDurationMin = 0;

  for (let segIdx = 0; segIdx < segments.length; segIdx++) {
    const segment = segments[segIdx];
    const sport = segment.sport;
    const durationMin = segment.duration_minutes;
    const durationH = durationMin / 60;
    const met = getSegmentMET(segment);
    const intensityDist = input.intensity_distribution
      ? getIntensityDistribution(input.intensity_distribution, met)
      : intensityDistFromLabel(segment.intensity || "moderate");

    cumulativeDurationMin += durationMin;

    const prevSport = segIdx > 0 ? segments[segIdx - 1].sport : null;
    const brickPenalty = (sport === "running" && prevSport === "cycling")
      ? 0.80
      : 1.0;

    const grossCal = calculateGrossCalories(weightKg, durationMin, met);
    const segDistKm = getSegmentDistanceKm(segment);
    const segDistMi = getSegmentDistanceMiles(segment);
    let speedKph: number | undefined;
    if (sport === "cycling" && segment.speed_mph) {
      speedKph = segment.speed_mph * MI_TO_KM;
    }
    const netCal = calculateNetCalories(sport, weightKg, segDistKm, speedKph);

    totalGrossCalories += grossCal;
    totalNetCalories += netCal;
    totalDistanceKm += segDistKm;
    totalDistanceMi += segDistMi;

    if (sport === "swimming") {
      duringSegments.push({
        segment_order: segment.order,
        sport,
        duration_minutes: durationMin,
        carbs_g: 0,
        carbs_low_g: 0,
        carbs_high_g: 0,
        carbs_rate_g_per_h: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 0,
        sodium_low_mg: 0,
        sodium_high_mg: 0,
        water_ml: 0,
        water_low_ml: 0,
        water_high_ml: 0,
        food_categories: ["during_swimming"],
        // Transparency fields — zeroed for swim
        raw_band_low_g_per_h: 0,
        raw_band_high_g_per_h: 0,
        scaled_band_low_g_per_h: 0,
        scaled_band_high_g_per_h: 0,
        gut_multiplier: 0,
        sport_ceiling_g_per_h: 0,
        brick_penalty: 1.0,
        cumulative_duration_min: cumulativeDurationMin,
      });
    } else {
      // Use total brick duration for carb band lookup so each segment's
      // rate reflects the full event length, not just the individual leg.
      const carbResult = calculateDuringWorkoutCarbRate(
        totalDurationMin,
        sport,
        gutTraining,
        intensityDist,
      );
      const hydrationResult = calculateDuringWorkoutHydration(
        durationH,
        sweatRateCategory,
        sweatSodiumCat,
        input.temp_c ?? null,
        input.humidity_pct ?? null,
      );
      const segmentCarbRateOverride = resolveBrickSegmentCarbRateOverride(
        segment,
        ov,
      );
      const adjustedCarbRate = segmentCarbRateOverride !== undefined
        ? segmentCarbRateOverride
        : (carbResult.rate_gph * brickPenalty);

      // Per-segment carb ranges based on scaled band ± brick penalty
      const segCarbsLow = Math.round(carbResult.band_low * brickPenalty * durationH);
      const segCarbsHigh = Math.round(carbResult.band_high * brickPenalty * durationH);

      duringSegments.push({
        segment_order: segment.order,
        sport,
        duration_minutes: durationMin,
        carbs_g: Math.round(adjustedCarbRate * durationH),
        carbs_low_g: segCarbsLow,
        carbs_high_g: segCarbsHigh,
        carbs_rate_g_per_h: Math.round(adjustedCarbRate * 10) / 10,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: hydrationResult.sodium_total_mg,
        sodium_low_mg: Math.round(hydrationResult.sodium_total_mg * 0.8),
        sodium_high_mg: Math.round(hydrationResult.sodium_total_mg * 1.2),
        water_ml: hydrationResult.hydration_total_ml,
        water_low_ml: Math.round(hydrationResult.hydration_total_ml * 0.85),
        water_high_ml: Math.round(hydrationResult.hydration_total_ml * 1.15),
        food_categories: [`during_${sport}`],
        // Transparency fields
        raw_band_low_g_per_h: carbResult.raw_band_low,
        raw_band_high_g_per_h: carbResult.raw_band_high,
        scaled_band_low_g_per_h: carbResult.band_low,
        scaled_band_high_g_per_h: carbResult.band_high,
        gut_multiplier: carbResult.gut_multiplier,
        sport_ceiling_g_per_h: carbResult.sport_ceiling,
        brick_penalty: brickPenalty,
        cumulative_duration_min: cumulativeDurationMin,
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
    const transitionName = i === 0 ? "T1" : "T2";
    let transitionCarbs: number,
      transitionSodium: number,
      transitionWater: number;
    if (totalDurationMin < 90) {
      transitionCarbs = 0;
      transitionSodium = 0;
      transitionWater = 0;
    } else if (totalDurationMin < 180) {
      transitionCarbs = 0;
      transitionSodium = 0;
      transitionWater = 50;
    } else {
      const carbsPerKg = i === 0 ? 0.3 : 0.35;
      transitionCarbs = Math.round(weightKg * carbsPerKg);
      if (totalDurationMin < 420) {
        if (i === 0) {
          transitionSodium = 150;
          transitionWater = 150;
        } else {
          transitionSodium = 100;
          transitionWater = 100;
        }
      } else {
        if (i === 0) {
          transitionSodium = 200;
          transitionWater = 200;
        } else {
          transitionSodium = 150;
          transitionWater = 150;
        }
      }
    }

    transitions.push({
      transition_name: transitionName,
      after_sport: segments[i].sport,
      before_sport: segments[i + 1].sport,
      carbs_g: transitionCarbs,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: transitionSodium,
      water_ml: transitionWater,
      timing_note: transitionName === "T1"
        ? "Within first 5-10 minutes after first segment"
        : "Final 5-10 minutes of second segment",
      food_categories: ["transition"],
    });
  }

  // Post-workout (same as V3)
  const postCarbs = calculatePostWorkoutCarbs(
    weightKg,
    totalDurationH,
    isFasted,
  );
  const postProtein = calculatePostWorkoutProtein(
    weightKg,
    totalDurationH,
    isFasted,
  );
  const actualSweatRateLph = calculateActualSweatRate(
    sweatRateCategory,
    input.temp_c ?? null,
    input.humidity_pct ?? null,
  );
  const sodiumConcMgPerL = sodiumConcentrationFromCategory(sweatSodiumCat);
  const totalDuringHydrationMl =
    duringSegments.reduce((sum, s) => sum + s.water_ml, 0) +
    transitions.reduce((sum, t) => sum + t.water_ml, 0);
  const postHydration = calculatePostWorkoutHydration(
    totalDurationH,
    actualSweatRateLph,
    sodiumConcMgPerL,
    totalDuringHydrationMl,
  );

  return {
    algorithm_version: "v4",
    activity_type: "brick",
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
