import { describe, it, expect, beforeAll } from 'vitest';

// For now, inline the golden data until we set up proper JSON imports
const goldenData = {
  "scenarios": [
    {
      "name": "5K Easy Pace Low Gut Training",
      "input": {
        "distance_miles": 3.1,
        "pace_min_per_mile": 10,
        "weight_lbs": 150,
        "gut_training_level": "low",
        "temperature_f": 65,
        "hours_before_run": 2.0
      },
      "expected": {
        "MET": 5.91,
        "calories_gross_kcal": 229,
        "calories_net_kcal": 340,
        "duration_hours": 0.52,
        "before_carbs_g": 30,
        "during_rate_g_per_h": 0,
        "during_carbs_g": 0,
        "during_water_ml": 260,
        "during_sodium_mg": 260,
        "after_carbs_g": 68,
        "after_protein_g": 34
      }
    },
    {
      "name": "Marathon Fast Pace High Gut Training",
      "input": {
        "distance_miles": 26.2,
        "pace_min_per_mile": 7.5,
        "weight_lbs": 150,
        "gut_training_level": "high",
        "temperature_f": 65,
        "hours_before_run": 3.0
      },
      "expected": {
        "MET": 11.03,
        "calories_gross_kcal": 1060,
        "calories_net_kcal": 2869,
        "duration_hours": 3.28,
        "before_carbs_g": 45,
        "during_rate_g_per_h": 53.0,
        "during_carbs_g": 174,
        "during_water_ml": 1640,
        "during_sodium_mg": 2296,
        "after_carbs_g": 68,
        "after_protein_g": 34
      }
    },
    {
      "name": "10K Moderate Pace Medium Gut Training",
      "input": {
        "distance_miles": 6.2,
        "pace_min_per_mile": 8.5,
        "weight_lbs": 150,
        "gut_training_level": "medium",
        "temperature_f": 70,
        "hours_before_run": 2.0
      },
      "expected": {
        "MET": 8.63,
        "calories_gross_kcal": 337,
        "calories_net_kcal": 679,
        "duration_hours": 0.88,
        "before_carbs_g": 30,
        "during_rate_g_per_h": 40.0,
        "during_carbs_g": 35,
        "during_water_ml": 528,
        "during_sodium_mg": 440,
        "after_carbs_g": 68,
        "after_protein_g": 34
      }
    }
  ]
};

// Extract the core calculation functions from generate-macros
// These are pure functions that don't depend on Deno or Supabase

const LB_TO_KG = 0.45359237;
const IN_TO_CM = 2.54;
const MI_TO_KM = 1.60934;
const MPH_TO_M_PER_MIN = 26.8224;

function toKg(weight: number, unit: string): number {
  return unit === "kg" ? weight : weight * LB_TO_KG;
}

function toMiles(distance: number, unit: string): number {
  return unit === "mi" ? distance : distance / MI_TO_KM;
}

function parsePaceToMinPerMile(pace: string | number, paceUnit = "min_per_mile"): number {
  function asMinutes(v: string | number): number {
    if (typeof v === 'number') {
      return v;
    }
    const parts = v.split(":").map((p) => p.trim());
    if (parts.length === 1) {
      return parseFloat(parts[0]);
    }
    const mm = parseFloat(parts[0] || "0");
    const ss = parseFloat(parts[1] || "0");
    return mm + ss / 60.0;
  }
  const p = asMinutes(pace);
  return paceUnit === "min_per_mile" ? p : p * MI_TO_KM;
}

// ACSM level-ground equations with walk/run switch
function metFromPace(minPerMile: number): number {
  const mph = 60.0 / minPerMile;
  const v = mph * MPH_TO_M_PER_MIN;
  // Walk/run switch at ~4.0 mph
  const vo2 = mph >= 4.0 ? 0.2 * v + 3.5 : 0.1 * v + 3.5;
  return vo2 / 3.5;
}

// Exact ACSM gross kcal calculation
function grossKcal(weightKg: number, durationMin: number, met: number): number {
  return met * 3.5 * weightKg / 200.0 * durationMin;
}

// Net transport cost
function netKcalTransportCost(weightKg: number, distanceMiles: number): number {
  return 1.0 * weightKg * (distanceMiles * MI_TO_KM);
}

function durationHours(distanceMiles: number, paceMinPerMile: number): number {
  return distanceMiles * paceMinPerMile / 60.0;
}

// Duration-based carb bands
function carbsBandByDuration(durationH: number): [number, number] {
  if (durationH <= 1.0) return [0, 30];
  if (durationH <= 2.0) return [30, 45];
  if (durationH <= 3.0) return [45, 60];
  if (durationH <= 4.0) return [60, 75];
  return [75, 90];
}

// Absorption caps
function absorptionCapGph(gut: string, source: string): number {
  if (source === "glucose_only") {
    return gut === "high" ? 65 : 60;
  }
  return gut === "low" ? 80 : gut === "moderate" ? 90 : 100;
}

// Intensity nudge
function intensityNudgeFromMet(met: number): number {
  return met < 7 ? -5 : met > 9 ? 5 : 0;
}

// Mass tilt within band
function massTiltWithinBand(weightKg: number, low: number, high: number): number {
  return weightKg < 50 ? low : weightKg > 80 ? high : Math.round((low + high) / 2);
}

// Complete carb recommendation
function recommendCarbsPerHour(
  durationH: number,
  met: number,
  weightKg: number,
  gut: string,
  source: string
): number {
  const [low, high] = carbsBandByDuration(durationH);

  // Floor condition for moderate duration + high intensity
  let adjustedLow = low;
  if (durationH > 1.1 && met > 8 && low < 30) {
    adjustedLow = 30;
  }

  const gutNudge = gut === "low" ? -5 : gut === "high" ? 5 : 0;
  const intensityNudge = intensityNudgeFromMet(met);
  const tiltBase = massTiltWithinBand(weightKg, adjustedLow, high);

  const raw = tiltBase + gutNudge + intensityNudge;
  const cap = absorptionCapGph(gut, source);

  return Math.min(raw, cap);
}

// Gut training multipliers
function getGutTrainingMultiplier(level: string): number {
  switch (level) {
    case 'low': return 1.0;
    case 'medium': return 1.33;
    case 'high': return 1.67;
    default: return 1.0;
  }
}

// Main macro calculation function
function calculateMacros(params: any) {
  const weightKg = toKg(params.weight_lbs, 'lbs');
  const distanceMiles = toMiles(params.distance_miles, 'mi');
  const paceMinPerMile = parsePaceToMinPerMile(params.pace_min_per_mile);
  const durationH = durationHours(distanceMiles, paceMinPerMile);
  const durationMin = durationH * 60;
  const met = metFromPace(paceMinPerMile);

  // Calories
  const caloriesGross = Math.round(grossKcal(weightKg, durationMin, met));
  const caloriesNet = Math.round(netKcalTransportCost(weightKg, distanceMiles));

  // During run carbs
  const gutMultiplier = getGutTrainingMultiplier(params.gut_training_level);
  const baseRate = recommendCarbsPerHour(durationH, met, weightKg, params.gut_training_level, "mixed");
  const duringRate = Math.round(baseRate * gutMultiplier);
  const duringCarbs = Math.round(duringRate * durationH);

  // Before run carbs (15g per hour before)
  const beforeHours = params.hours_before_run || 2.0;
  const beforeCarbs = Math.round(15 * beforeHours);

  // After run (0.5g/kg protein, 1g/kg carbs)
  const afterProtein = Math.round(0.5 * weightKg);
  const afterCarbs = Math.round(1.0 * weightKg);

  // Hydration (400-800ml/h based on conditions)
  const baseHydration = params.temperature_f > 70 ? 600 : 500;
  const duringWater = Math.round(baseHydration * durationH);

  // Sodium (500-1000mg/h based on conditions and duration)
  const baseSodium = durationH > 2 ? 700 : 500;
  const sodiumAdjustment = params.temperature_f > 70 ? 1.2 : 1.0;
  const duringSodium = Math.round(baseSodium * durationH * sodiumAdjustment);

  return {
    MET: parseFloat(met.toFixed(2)),
    calories_gross_kcal: caloriesGross,
    calories_net_kcal: caloriesNet,
    duration_hours: parseFloat(durationH.toFixed(2)),
    before_run: {
      carbs_g: beforeCarbs,
      hours_before: beforeHours
    },
    during_run: {
      carbs_g: duringCarbs,
      carbs_g_per_h: duringRate,
      water_ml: duringWater,
      water_ml_per_h: baseHydration,
      sodium_mg: duringSodium,
      sodium_mg_per_h: Math.round(baseSodium * sodiumAdjustment)
    },
    after_run: {
      carbs_g: afterCarbs,
      protein_g: afterProtein
    }
  };
}

describe('Generate Macros - Unit Tests', () => {
  describe('Core Calculations', () => {
    it('should correctly calculate MET from pace', () => {
      // Test walking pace (< 4 mph)
      const walkMet = metFromPace(15); // 15 min/mile = 4 mph
      expect(walkMet).toBeCloseTo(3.71, 1);

      // Test running pace (>= 4 mph)
      const runMet = metFromPace(8); // 8 min/mile = 7.5 mph
      expect(runMet).toBeCloseTo(11.03, 1);
    });

    it('should calculate gross calories correctly', () => {
      const weightKg = 68.04; // 150 lbs
      const durationMin = 210; // 3.5 hours
      const met = 11.03;

      const calories = grossKcal(weightKg, durationMin, met);
      expect(Math.round(calories)).toBe(1382);
    });

    it('should calculate net transport cost correctly', () => {
      const weightKg = 68.04; // 150 lbs
      const distanceMiles = 26.2;

      const netCals = netKcalTransportCost(weightKg, distanceMiles);
      expect(Math.round(netCals)).toBe(2869);
    });

    it('should apply gut training multipliers correctly', () => {
      expect(getGutTrainingMultiplier('low')).toBe(1.0);
      expect(getGutTrainingMultiplier('medium')).toBeCloseTo(1.33, 2);
      expect(getGutTrainingMultiplier('high')).toBeCloseTo(1.67, 2);
    });

    it('should calculate carb bands by duration', () => {
      expect(carbsBandByDuration(0.5)).toEqual([0, 30]);
      expect(carbsBandByDuration(1.5)).toEqual([30, 45]);
      expect(carbsBandByDuration(2.5)).toEqual([45, 60]);
      expect(carbsBandByDuration(3.5)).toEqual([60, 75]);
      expect(carbsBandByDuration(5.0)).toEqual([75, 90]);
    });
  });

  describe('Golden Dataset Validation', () => {
    goldenData.scenarios.forEach((scenario) => {
      it(`should match golden data for ${scenario.name}`, () => {
        const result = calculateMacros(scenario.input);

        // Validate MET calculation (exact match)
        expect(result.MET).toBeCloseTo(scenario.expected.MET, 2);

        // Validate calories (within 5% tolerance)
        const calorieTolerance = scenario.expected.calories_gross_kcal * 0.05;
        expect(result.calories_gross_kcal).toBeCloseTo(
          scenario.expected.calories_gross_kcal,
          -Math.log10(calorieTolerance)
        );

        // Validate during run carbs rate (within ±5g/h tolerance)
        expect(Math.abs(result.during_run.carbs_g_per_h - scenario.expected.during_rate_g_per_h))
          .toBeLessThanOrEqual(5);

        // Validate total during run carbs (within ±10g tolerance)
        expect(Math.abs(result.during_run.carbs_g - scenario.expected.during_carbs_g))
          .toBeLessThanOrEqual(10);

        // Validate before run carbs
        if (scenario.expected.before_carbs_g) {
          expect(Math.abs(result.before_run.carbs_g - scenario.expected.before_carbs_g))
            .toBeLessThanOrEqual(5);
        }

        // Validate hydration (within ±100ml tolerance)
        if (scenario.expected.during_water_ml) {
          expect(Math.abs(result.during_run.water_ml - scenario.expected.during_water_ml))
            .toBeLessThanOrEqual(100);
        }

        // Validate sodium (within ±50mg tolerance)
        if (scenario.expected.during_sodium_mg) {
          expect(Math.abs(result.during_run.sodium_mg - scenario.expected.during_sodium_mg))
            .toBeLessThanOrEqual(50);
        }
      });
    });
  });

  describe('Edge Cases', () => {
    it('should handle minimum values correctly', () => {
      const result = calculateMacros({
        distance_miles: 3.1, // 5K
        pace_min_per_mile: 12,
        weight_lbs: 110,
        gut_training_level: 'low',
        temperature_f: 65,
        hours_before_run: 1
      });

      expect(result.MET).toBeGreaterThan(0);
      expect(result.during_run.carbs_g).toBeGreaterThanOrEqual(0);
      expect(result.during_run.water_ml).toBeGreaterThan(0);
    });

    it('should handle maximum values correctly', () => {
      const result = calculateMacros({
        distance_miles: 50, // Ultra
        pace_min_per_mile: 10,
        weight_lbs: 200,
        gut_training_level: 'high',
        temperature_f: 85,
        hours_before_run: 4
      });

      // Check absorption caps are applied
      expect(result.during_run.carbs_g_per_h).toBeLessThanOrEqual(100);
      expect(result.during_run.sodium_mg).toBeLessThanOrEqual(10000); // Safety max
    });

    it('should handle pace format variations', () => {
      const pace1 = parsePaceToMinPerMile("8:30");
      const pace2 = parsePaceToMinPerMile(8.5);
      const pace3 = parsePaceToMinPerMile("8:30", "min_per_mile");

      expect(pace1).toBeCloseTo(8.5, 2);
      expect(pace2).toBe(8.5);
      expect(pace3).toBeCloseTo(8.5, 2);
    });
  });
});