/**
 * Environment classification and sweat rate calculations.
 *
 * Sources: Barnes/Baker 2019 (sweat rate percentiles, n=1303),
 * Baker 2016 (sodium concentration percentiles, n=506).
 */

// ============================================================================
// Constants
// ============================================================================

export const SWEAT_RATE_LPH: Record<string, number> = {
  light: 0.90,
  medium: 1.28,
  heavy: 1.66,
};

export const SODIUM_CONC_MG_PER_L: Record<string, number> = {
  low: 650,
  average: 825,
  // 'medium' accepted as legacy alias for 'average'
  medium: 825,
  high: 1000,
};

export const SWIMMING_SWEAT_MODIFIER = 0.4;

const TEMP_BASELINE_C = 22;
const TEMP_COEFFICIENT = 0.04;
const TEMP_MULT_MIN = 0.50;
const TEMP_MULT_MAX = 1.80;

const HUMIDITY_BASELINE_PCT = 50;
const HUMIDITY_COEFFICIENT = 0.002;
const HUMIDITY_MULT_MIN = 1.0;
const HUMIDITY_MULT_MAX = 1.10;

const INDOOR_MULTIPLIER = 1.30;

const OVERALL_RATE_MIN = 0.3;
const OVERALL_RATE_MAX = 3.0;

// ============================================================================
// Helpers
// ============================================================================

function clamp(val: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, val));
}

// ============================================================================
// Base rate / sodium lookups
// ============================================================================

/**
 * Spec base sweat rates: LIGHT=0.90, MEDIUM=1.28, HEAVY=1.66 L/hr.
 */
export function baseSweatRateFromCategory(category: string): number {
  return SWEAT_RATE_LPH[category.toLowerCase()] ?? SWEAT_RATE_LPH['medium'];
}

/**
 * Sodium concentrations: LOW=650, AVERAGE=825 (medium alias), HIGH=1000 mg/L.
 */
export function sodiumConcentrationFromCategory(category: string): number {
  return SODIUM_CONC_MG_PER_L[category.toLowerCase()] ?? SODIUM_CONC_MG_PER_L['average'];
}

// ============================================================================
// Replacement % by total workout duration
// ============================================================================

/**
 * Duration-scaled replacement percentage lookup.
 *
 * <60 min  → 0.30
 * 60–90    → 0.50  (inclusive of 90, per Example 2)
 * 91–150   → 0.60
 * 151–240  → 0.70
 * 240+     → 0.80
 */
export function replacementPctForDuration(durationMin: number): number {
  if (durationMin < 60) return 0.30;
  if (durationMin <= 90) return 0.50;
  if (durationMin <= 150) return 0.60;
  if (durationMin < 240) return 0.70;
  return 0.80;
}

// ============================================================================
// Effective sweat rate calculation
// ============================================================================

/**
 * Calculate effective sweat rate in L/hr.
 *
 * @param baseCategory - 'light' | 'medium' | 'heavy'
 * @param tempC - ambient temperature (°C)
 * @param humidityPct - relative humidity (0-100)
 * @param isIndoor - indoor environment flag (adds 1.30× multiplier)
 * @param knownSweatRateMlPerHour - optional override (replaces base rate but
 *   still goes through temp/humidity/indoor multipliers and overall clamp)
 * @param knownSodiumConcMgPerL - not used here but accepted for interface parity
 *
 * Formula:
 *   base = knownSweatRateMlPerHour/1000  OR  SWEAT_RATE_LPH[baseCategory]
 *   temp_mult     = clamp(1.0 + (tempC - 22)*0.04, 0.50, 1.80)
 *   humidity_mult = clamp(1.0 + max(0, h-50)*0.002, 1.0, 1.10)
 *   indoor_mult   = 1.30 if isIndoor else 1.0
 *   effective     = clamp(base * temp_mult * humidity_mult * indoor_mult, 0.3, 3.0)
 */
export function calculateActualSweatRate(
  baseCategory: string,
  tempC: number | null,
  humidityPct: number | null,
  isIndoor: boolean = false,
  knownSweatRateMlPerHour: number | null = null,
  _knownSodiumConcMgPerL: number | null = null,
): number {
  return calculateSweatRateBreakdown(
    baseCategory,
    tempC,
    humidityPct,
    isIndoor,
    knownSweatRateMlPerHour,
  ).effective_lph;
}

export interface SweatRateBreakdown {
  base_lph: number;
  is_tested: boolean;
  temp_mult: number;
  humidity_mult: number;
  indoor_mult: number;
  effective_lph: number;
}

/**
 * Return the intermediate multipliers used to produce the effective sweat
 * rate, so the transparency UI can render a step-by-step calculation.
 */
export function calculateSweatRateBreakdown(
  baseCategory: string,
  tempC: number | null,
  humidityPct: number | null,
  isIndoor: boolean = false,
  knownSweatRateMlPerHour: number | null = null,
): SweatRateBreakdown {
  const baseRate = knownSweatRateMlPerHour !== null
    ? knownSweatRateMlPerHour / 1000
    : baseSweatRateFromCategory(baseCategory);

  const t = tempC ?? TEMP_BASELINE_C;
  const rawTempMult = 1.0 + (t - TEMP_BASELINE_C) * TEMP_COEFFICIENT;
  const tempMult = clamp(rawTempMult, TEMP_MULT_MIN, TEMP_MULT_MAX);

  const h = humidityPct ?? HUMIDITY_BASELINE_PCT;
  const rawHumidityMult =
    1.0 + Math.max(0, h - HUMIDITY_BASELINE_PCT) * HUMIDITY_COEFFICIENT;
  const humidityMult = clamp(rawHumidityMult, HUMIDITY_MULT_MIN, HUMIDITY_MULT_MAX);

  const indoorMult = isIndoor ? INDOOR_MULTIPLIER : 1.0;

  const rawRate = baseRate * tempMult * humidityMult * indoorMult;
  const effective = Math.round(
    clamp(rawRate, OVERALL_RATE_MIN, OVERALL_RATE_MAX) * 1000,
  ) / 1000;

  return {
    base_lph: Math.round(baseRate * 1000) / 1000,
    is_tested: knownSweatRateMlPerHour !== null,
    temp_mult: Math.round(tempMult * 100) / 100,
    humidity_mult: Math.round(humidityMult * 100) / 100,
    indoor_mult: indoorMult,
    effective_lph: effective,
  };
}

/**
 * Short label for the replacement-% tier, for transparency UI.
 * Matches the "< 60 min", "60–90", "90–150", "150–240", "240+ min" tier bands.
 */
export function replacementBandLabel(durationMin: number): string {
  if (durationMin < 60) return '< 60 min';
  if (durationMin <= 90) return '60–90 min';
  if (durationMin <= 150) return '90–150 min';
  if (durationMin < 240) return '150–240 min';
  return '240+ min';
}

// ============================================================================
// Legacy API (kept for backcompat with callers that pass 3 args)
// ============================================================================

/**
 * Classify environment — retained for callers in index.ts that use it.
 */
export function classifyEnvironment(
  tempC: number | null,
  humidityPct: number | null,
): [number, string] {
  if (tempC === null && humidityPct === null) return [1.0, "moderate"];
  const t = tempC ?? 20.0;
  const h = humidityPct ?? 60.0;
  if (t <= 10) return [0.85, "cool"];
  if (t <= 20 && h <= 60) return [1.0, "temperate"];
  if (t <= 25 || (h > 60 && h <= 75)) return [1.1, "warm"];
  if (t <= 30 || (h > 75 && h <= 85)) return [1.2, "hot"];
  return [1.3, "very_hot"];
}
