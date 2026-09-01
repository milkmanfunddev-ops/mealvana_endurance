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
  sodiumConcentrationFromCategory,
  replacementPctForDuration,
  runningMETFromPace,
  cyclingMETFromSpeed,
  swimmingMETFromPace,
  calculateGrossCalories,
  calculateNetCalories,
  calculateDuringWorkoutCarbRate,
  calculatePostWorkoutCarbs,
  calculatePostWorkoutProtein,
  calculatePostWorkoutHydration,
  getIntensityDistribution,
  type MacroInputV4,
  type NutritionOverrides,
} from "./single-sport.ts";
import {
  SWIMMING_SWEAT_MODIFIER,
  calculateSweatRateBreakdown,
  replacementBandLabel,
} from "../_shared/nutrition/sweat-hydration.ts";
import type { PreWorkoutOverlaidTargets } from "./pre-workout.ts";

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

// ============================================================================
// Brick Hydration (new spec algorithm)
// ============================================================================

export interface BrickHydrationSegmentInput {
  sport: string;
  durationMin: number;
  order: number;
}

export interface BrickHydrationInput {
  weightKg: number;
  segments: BrickHydrationSegmentInput[];
  sweatRateCategory: string;
  sweatSodiumCat: string;
  tempC: number | null;
  humidityPct: number | null;
  isIndoor: boolean;
  knownSweatRateMlPerHour: number | null;
  knownSodiumConcMgPerL: number | null;
}

interface BrickHydrationSegmentResult {
  sport: string;
  order: number;
  duration_min: number;
  hydration_rate_mlph: number;
  sodium_rate_mgph: number;
  ceiling_ml_hr: number;
  floor_ml_hr: number;
  effective_sweat_rate_lph: number;
}

interface BrickHydrationTransitionResult {
  transition_name: string;
  after_sport: string;
  before_sport: string;
  water_ml: number;
  sodium_mg: number;
}

export interface BrickHydrationResult {
  segments: BrickHydrationSegmentResult[];
  transitions: BrickHydrationTransitionResult[];
  safety_flags: string[];
  effective_sweat_rate_lph: number;
  sodium_conc_mg_per_l: number;
  replacement_pct: number;
  is_tested: boolean;
  is_tested_sodium: boolean;
  // Transparency breakdown
  base_sweat_rate_lph: number;
  temp_mult: number;
  humidity_mult: number;
  indoor_mult: number;
  replacement_band: string;
}

const GI_CEILING_ML_HR: Record<string, number> = {
  running: 800,
  cycling: 1200,
  swimming: 0,
};

const TRANSITION_FLUID_ML = 300;

/**
 * Calculate multi-segment (brick) hydration targets per spec.
 *
 * Algorithm:
 * 1. Compute effective sweat rate (with known-rate override, temp/humidity/indoor mults)
 * 2. Total duration → replacement %
 * 3. Per-segment sweat losses (swim uses 0.4× modifier)
 * 4. Detect transitions: swim→bike = T1, bike→run = T2, each gets 300 ml fixed
 * 5. Subtract transition intake from required_total and floor_total
 * 6. Distribute remaining across drinkable hours (non-swim segments)
 * 7. Apply per-segment ceilings (min(sport GI, 100% sweat rate))
 * 8. Run→bike redistribution if run ceiling hit
 * 9. Safety flags for >2% deficit
 */
export function calculateBrickHydration(
  input: BrickHydrationInput,
): BrickHydrationResult {
  const {
    weightKg,
    segments,
    sweatRateCategory,
    sweatSodiumCat,
    tempC,
    humidityPct,
    isIndoor,
    knownSweatRateMlPerHour,
    knownSodiumConcMgPerL,
  } = input;

  const safety_flags: string[] = [];

  // Effective sweat rate (with breakdown for transparency)
  const breakdown = calculateSweatRateBreakdown(
    sweatRateCategory, tempC, humidityPct, isIndoor, knownSweatRateMlPerHour,
  );
  const effectiveSweatRateLph = breakdown.effective_lph;
  const effectiveSweatRateMlph = effectiveSweatRateLph * 1000;

  // Sodium concentration
  const sodiumConcMgPerL = knownSodiumConcMgPerL ?? sodiumConcentrationFromCategory(sweatSodiumCat);

  // Total duration → replacement %
  const totalDurationMin = segments.reduce((s, seg) => s + seg.durationMin, 0);
  const replacementPct = replacementPctForDuration(totalDurationMin);

  // Per-segment sweat losses (swim uses 0.4× modifier)
  let totalLossMl = 0;
  for (const seg of segments) {
    const durationH = seg.durationMin / 60;
    if (seg.sport.toLowerCase() === 'swimming') {
      totalLossMl += effectiveSweatRateMlph * SWIMMING_SWEAT_MODIFIER * durationH;
    } else {
      totalLossMl += effectiveSweatRateMlph * durationH;
    }
  }

  // Detect transitions (ordered by segment)
  // Transition occurs between each adjacent pair of segments
  // swim→bike = T1, bike→run = T2
  const transitionsRaw: Array<{ index: number; afterSport: string; beforeSport: string }> = [];
  for (let i = 0; i < segments.length - 1; i++) {
    const afterSport = segments[i].sport.toLowerCase();
    const beforeSport = segments[i + 1].sport.toLowerCase();

    // Naming convention: swim→bike = T1, bike→run = T2, otherwise index-based
    let transitionName: string;
    if (afterSport === 'swimming' && beforeSport === 'cycling') {
      transitionName = 'T1';
    } else if (afterSport === 'cycling' && beforeSport === 'running') {
      transitionName = 'T2';
    } else {
      transitionName = `T${i + 1}`;
    }
    transitionsRaw.push({ index: i, afterSport, beforeSport });
    // Store with the name for output
    transitionsRaw[transitionsRaw.length - 1] = {
      index: i,
      afterSport,
      beforeSport,
      // deno-lint-ignore no-explicit-any
      ...(transitionName ? { name: transitionName } as any : {}),
    };
  }

  const transitionCount = transitionsRaw.length;
  const totalTransitionFluidMl = transitionCount * TRANSITION_FLUID_ML;

  // Required total based on replacement %
  const requiredTotalMl = totalLossMl * replacementPct;
  // Floor: covers deficit down to 2% BW
  const maxDeficitMl = weightKg * 1000 * 0.02;
  const rawFloorTotalMl = totalLossMl - maxDeficitMl;
  const floorTotalMl = Math.max(0, rawFloorTotalMl);

  // Subtract transition intake
  const remainingRequired = Math.max(0, requiredTotalMl - totalTransitionFluidMl);
  const remainingFloor = Math.max(0, floorTotalMl - totalTransitionFluidMl);

  // Drinkable hours: non-swim segments only
  const drinkableMinutes = segments
    .filter(s => s.sport.toLowerCase() !== 'swimming')
    .reduce((s, seg) => s + seg.durationMin, 0);
  const drinkableHours = drinkableMinutes / 60;

  // Recommended ml/hr across drinkable segments
  let recommendedMlHr = drinkableHours > 0 ? Math.round(remainingRequired / drinkableHours) : 0;
  const floorMlHr = drinkableHours > 0 ? Math.round(remainingFloor / drinkableHours) : 0;

  // Apply floor (raises target if needed)
  recommendedMlHr = Math.max(recommendedMlHr, floorMlHr);

  // Per-segment ceiling = min(sport GI, 100% sweat rate)
  const segmentCeilings: Record<string, number> = {
    cycling: Math.round(Math.min(GI_CEILING_ML_HR['cycling'], effectiveSweatRateMlph)),
    running: Math.round(Math.min(GI_CEILING_ML_HR['running'], effectiveSweatRateMlph)),
    swimming: 0,
  };

  // Apply per-segment ceilings — initially all drinkable segments get recommendedMlHr
  // Then do run→bike redistribution
  const segmentRates: Record<number, number> = {};
  for (const seg of segments) {
    const sport = seg.sport.toLowerCase();
    if (sport === 'swimming') {
      segmentRates[seg.order] = 0;
    } else {
      const ceiling = segmentCeilings[sport] ?? GI_CEILING_ML_HR['running'];
      segmentRates[seg.order] = Math.min(recommendedMlHr, ceiling);
    }
  }

  // Run→bike redistribution
  // Per spec §6.3: redistribute when the run leg's *recommended rate* exceeds
  // its ceiling, not just when the floor does. Mid-duration hot bricks
  // (replacement % around 50–60) can have `recommended > run_ceiling` even
  // when the floor stays below — those used to silently miss redistribution.
  // The shift amount is driven by whichever is larger (floor or recommended).
  const nonSwimSegs = segments.filter(s => s.sport.toLowerCase() !== 'swimming');

  let redistributionFailed = false;
  for (const seg of nonSwimSegs) {
    if (seg.sport.toLowerCase() !== 'running') continue;

    const runCeiling = segmentCeilings['running'];
    const runTrigger = Math.max(floorMlHr, recommendedMlHr);
    if (runTrigger > runCeiling) {
      // Shortfall from run
      const runDurationH = seg.durationMin / 60;
      const shortfallTotal = (runTrigger - runCeiling) * runDurationH;

      // Distribute to bike segments
      const bikeSegs = nonSwimSegs.filter(s => s.sport.toLowerCase() === 'cycling');
      const totalBikeHours = bikeSegs.reduce((s, b) => s + b.durationMin / 60, 0);

      if (totalBikeHours > 0) {
        const addPerHr = shortfallTotal / totalBikeHours;
        const bikeCeiling = segmentCeilings['cycling'];
        for (const bikeSeg of bikeSegs) {
          const current = segmentRates[bikeSeg.order];
          const newRate = Math.min(current + addPerHr, bikeCeiling);
          segmentRates[bikeSeg.order] = Math.round(newRate);
        }
      }

      // Cap run at ceiling
      segmentRates[seg.order] = runCeiling;

      // Check if shortfall remains
      const actualBikeIntake = nonSwimSegs
        .filter(s => s.sport.toLowerCase() === 'cycling')
        .reduce((s, b) => s + segmentRates[b.order] * b.durationMin / 60, 0);
      const actualRunIntake = segmentRates[seg.order] * runDurationH;
      const totalActualIntake = actualBikeIntake + actualRunIntake + totalTransitionFluidMl;
      const netDeficit = totalLossMl - totalActualIntake;

      if (netDeficit > maxDeficitMl) {
        redistributionFailed = true;
      }
    }
  }

  if (redistributionFailed) {
    safety_flags.push('Even at maximum intake on all segments, you will exceed 2% BW loss.');
  }

  // Calculate total intake for safety check
  let totalIntakeMl = totalTransitionFluidMl;
  for (const seg of segments) {
    const rate = segmentRates[seg.order] ?? 0;
    totalIntakeMl += rate * seg.durationMin / 60;
  }
  const netDeficitMl = totalLossMl - totalIntakeMl;
  if (weightKg > 0 && netDeficitMl > 0) {
    const deficitPct = netDeficitMl / (weightKg * 1000);
    if (deficitPct > 0.03) {
      // Spec §6.5 — emit the >3% flag once. When redistribution also failed,
      // the redistribution flag has already landed above, and the spec
      // intends both to stack (Example in §7 shows them consecutively).
      const deficitPctStr = (deficitPct * 100).toFixed(1);
      safety_flags.push(`Significant dehydration expected (>${deficitPctStr}% BW).`);
    }
  }

  // Build output segments
  const resultSegments: BrickHydrationSegmentResult[] = segments.map(seg => {
    const rate = segmentRates[seg.order] ?? 0;
    const sport = seg.sport.toLowerCase();
    const ceiling = segmentCeilings[sport] ?? 0;
    const sodiumRate = Math.round((rate / 1000) * sodiumConcMgPerL);
    // Per-segment effective sweat rate: swim uses 0.4× modifier
    const segEffectiveLph = sport === 'swimming'
      ? effectiveSweatRateLph * SWIMMING_SWEAT_MODIFIER
      : effectiveSweatRateLph;
    return {
      sport: seg.sport,
      order: seg.order,
      duration_min: seg.durationMin,
      hydration_rate_mlph: rate,
      sodium_rate_mgph: sodiumRate,
      ceiling_ml_hr: ceiling,
      floor_ml_hr: sport === 'swimming' ? 0 : floorMlHr,
      effective_sweat_rate_lph: Math.round(segEffectiveLph * 1000) / 1000,
    };
  });

  // Build output transitions
  const resultTransitions: BrickHydrationTransitionResult[] = transitionsRaw.map((t, idx) => {
    const afterSport = t.afterSport;
    const beforeSport = t.beforeSport;
    let transitionName: string;
    if (afterSport === 'swimming' && beforeSport === 'cycling') {
      transitionName = 'T1';
    } else if (afterSport === 'cycling' && beforeSport === 'running') {
      transitionName = 'T2';
    } else {
      transitionName = `T${idx + 1}`;
    }
    const sodiumMg = Math.round((TRANSITION_FLUID_ML / 1000) * sodiumConcMgPerL);
    return {
      transition_name: transitionName,
      after_sport: t.afterSport,
      before_sport: t.beforeSport,
      water_ml: TRANSITION_FLUID_ML,
      sodium_mg: sodiumMg,
    };
  });

  return {
    segments: resultSegments,
    transitions: resultTransitions,
    safety_flags,
    effective_sweat_rate_lph: effectiveSweatRateLph,
    sodium_conc_mg_per_l: sodiumConcMgPerL,
    replacement_pct: replacementPct,
    is_tested: knownSweatRateMlPerHour !== null,
    is_tested_sodium: knownSodiumConcMgPerL !== null,
    base_sweat_rate_lph: breakdown.base_lph,
    temp_mult: breakdown.temp_mult,
    humidity_mult: breakdown.humidity_mult,
    indoor_mult: breakdown.indoor_mult,
    replacement_band: replacementBandLabel(totalDurationMin),
  };
}

/** Round for the wire while preserving `null` ("no statement made"). */
function roundOrNull(value: number | null): number | null {
  return value === null ? null : Math.round(value);
}

export function calculateBrickMacrosV4(
  input: MacroInputV4,
  // Post-overlay targets: `sodium_*` is null (sodium SSOT v3) and `water_*` is
  // null on the hydration gate path. Brick only passes them through to the
  // response — it does no arithmetic on them.
  preTargets: PreWorkoutOverlaidTargets,
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

  // --- Brick hydration (new spec algorithm) ---
  // Run once for the whole brick; all per-segment hydration values come from here.
  const brickHydration = calculateBrickHydration({
    weightKg,
    segments: segments.map(s => ({
      sport: s.sport,
      durationMin: s.duration_minutes,
      order: s.order,
    })),
    sweatRateCategory,
    sweatSodiumCat,
    tempC: input.temp_c ?? null,
    humidityPct: input.humidity_pct ?? null,
    isIndoor: input.is_indoor ?? false,
    knownSweatRateMlPerHour: input.known_sweat_rate_ml_hr ?? null,
    knownSodiumConcMgPerL: input.known_sodium_concentration_mg_l ?? null,
  });

  // Build a lookup from segment order → hydration result
  const hydrationByOrder: Record<number, BrickHydrationSegmentResult> = {};
  for (const seg of brickHydration.segments) {
    hydrationByOrder[seg.order] = seg;
  }

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
    // Hydration transparency (from calculateBrickHydration)
    hydration_rate_ml_per_h: number;
    sodium_rate_mg_per_h: number;
    effective_sweat_rate_lph: number;
    sodium_conc_mg_per_l: number;
    floor_ml_hr: number;
    ceiling_ml_hr: number;
    safety_flags: string[];
    replacement_pct: number;
    replacement_band: string;
    is_tested: boolean;
    is_tested_sodium: boolean;
    base_sweat_rate_lph: number;
    temp_mult: number;
    humidity_mult: number;
    indoor_mult: number;
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

    // Hydration comes from calculateBrickHydration (total-duration-based)
    const segHydration = hydrationByOrder[segment.order];
    const hydRateMlph = segHydration?.hydration_rate_mlph ?? 0;
    const sodiumRateMgph = segHydration?.sodium_rate_mgph ?? 0;
    const ceilingMlHr = segHydration?.ceiling_ml_hr ?? 0;
    const floorMlHr = segHydration?.floor_ml_hr ?? 0;
    const effectiveSweatRateLph = segHydration?.effective_sweat_rate_lph ?? 0;
    // Total water and sodium for this segment from rate × duration
    const segWaterMl = Math.round(hydRateMlph * durationH);
    const segSodiumMg = Math.round(sodiumRateMgph * durationH);

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
        // Hydration transparency
        hydration_rate_ml_per_h: 0,
        sodium_rate_mg_per_h: 0,
        effective_sweat_rate_lph: effectiveSweatRateLph,
        sodium_conc_mg_per_l: brickHydration.sodium_conc_mg_per_l,
        floor_ml_hr: 0,
        ceiling_ml_hr: 0,
        safety_flags: brickHydration.safety_flags,
        replacement_pct: brickHydration.replacement_pct,
        replacement_band: brickHydration.replacement_band,
        is_tested: brickHydration.is_tested,
        is_tested_sodium: brickHydration.is_tested_sodium,
        base_sweat_rate_lph: brickHydration.base_sweat_rate_lph,
        temp_mult: brickHydration.temp_mult,
        humidity_mult: brickHydration.humidity_mult,
        indoor_mult: brickHydration.indoor_mult,
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
        sodium_mg: segSodiumMg,
        sodium_low_mg: Math.round(segSodiumMg * 0.8),
        sodium_high_mg: Math.round(segSodiumMg * 1.2),
        water_ml: segWaterMl,
        water_low_ml: Math.round(segWaterMl * 0.85),
        water_high_ml: Math.round(segWaterMl * 1.15),
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
        // Hydration transparency (from calculateBrickHydration)
        hydration_rate_ml_per_h: hydRateMlph,
        sodium_rate_mg_per_h: sodiumRateMgph,
        effective_sweat_rate_lph: effectiveSweatRateLph,
        sodium_conc_mg_per_l: brickHydration.sodium_conc_mg_per_l,
        floor_ml_hr: floorMlHr,
        ceiling_ml_hr: ceilingMlHr,
        safety_flags: brickHydration.safety_flags,
        replacement_pct: brickHydration.replacement_pct,
        replacement_band: brickHydration.replacement_band,
        is_tested: brickHydration.is_tested,
        is_tested_sodium: brickHydration.is_tested_sodium,
        base_sweat_rate_lph: brickHydration.base_sweat_rate_lph,
        temp_mult: brickHydration.temp_mult,
        humidity_mult: brickHydration.humidity_mult,
        indoor_mult: brickHydration.indoor_mult,
      });
    }
  }

  // Transitions — water_ml and sodium_mg come from calculateBrickHydration.
  // Carb logic is unchanged (based on total duration).
  // Build a lookup from transition_name → hydration result.
  const hydrationTransitionByName: Record<string, typeof brickHydration.transitions[0]> = {};
  for (const ht of brickHydration.transitions) {
    hydrationTransitionByName[ht.transition_name] = ht;
  }

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
    // Hydration transparency (propagated from brickHydration so the UI can
    // render the inherited sodium formula + known-rate badges on T1/T2 cards)
    sodium_conc_mg_per_l: number;
    is_tested: boolean;
    is_tested_sodium: boolean;
  }> = [];

  for (let i = 0; i < segments.length - 1; i++) {
    const afterSport = segments[i].sport.toLowerCase();
    const beforeSport = segments[i + 1].sport.toLowerCase();
    let transitionName: string;
    if (afterSport === 'swimming' && beforeSport === 'cycling') {
      transitionName = 'T1';
    } else if (afterSport === 'cycling' && beforeSport === 'running') {
      transitionName = 'T2';
    } else {
      transitionName = `T${i + 1}`;
    }

    // Carbs: preserve existing carb logic based on total duration (unchanged)
    let transitionCarbs: number;
    if (totalDurationMin < 90) {
      transitionCarbs = 0;
    } else if (totalDurationMin < 180) {
      transitionCarbs = 0;
    } else {
      const carbsPerKg = i === 0 ? 0.3 : 0.35;
      transitionCarbs = Math.round(weightKg * carbsPerKg);
    }

    // Water and sodium from calculateBrickHydration (fixed 300 ml + 0.3×sodiumConc mg)
    const ht = hydrationTransitionByName[transitionName];
    const transitionWaterMl = ht?.water_ml ?? 300;
    const transitionSodiumMg = ht?.sodium_mg ?? 0;

    transitions.push({
      transition_name: transitionName,
      after_sport: segments[i].sport,
      before_sport: segments[i + 1].sport,
      carbs_g: transitionCarbs,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: transitionSodiumMg,
      water_ml: transitionWaterMl,
      timing_note: transitionName === "T1"
        ? "Within first 5-10 minutes after first segment"
        : "Final 5-10 minutes of second segment",
      food_categories: ["transition"],
      sodium_conc_mg_per_l: brickHydration.sodium_conc_mg_per_l,
      is_tested: brickHydration.is_tested,
      is_tested_sodium: brickHydration.is_tested_sodium,
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
  // Use effective sweat rate and sodium concentration from calculateBrickHydration
  // (already accounts for indoor flag, known sweat rate, temp/humidity).
  const actualSweatRateLph = brickHydration.effective_sweat_rate_lph;
  const sodiumConcMgPerL = brickHydration.sodium_conc_mg_per_l;
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
        // Sodium is null by design (no pre-workout sodium target); fluid is
        // null on the hydration gate path. Rounding happens here, at the
        // response boundary — the engine itself is exact.
        sodium_mg: preTargets.sodium_mg,
        water_ml: roundOrNull(preTargets.water_ml),
        meal_type: preTargets.meal_type,
        // V4 range fields
        carbs_low_g: preTargets.carbs_low_g,
        carbs_high_g: preTargets.carbs_high_g,
        protein_low_g: preTargets.protein_low_g,
        protein_high_g: preTargets.protein_high_g,
        sodium_low_mg: preTargets.sodium_low_mg,
        sodium_high_mg: preTargets.sodium_high_mg,
        water_low_ml: roundOrNull(preTargets.water_low_ml),
        water_high_ml: roundOrNull(preTargets.water_high_ml),
        water_tiers: preTargets.water_tiers,
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
