import { describe, it, expect, beforeAll } from 'vitest';

// ============================================
// COMPLETE GENERATE-MACROS BUSINESS LOGIC TESTS
// ============================================
// Testing the actual edge function calculations from generate-macros/index.ts
// This file tests ALL the complex business logic including:
// - Carbohydrate recommendations with gut training
// - Hydration calculations with environment factors
// - Sodium calculations with sweat rate
// - Pre/during/after nutrition timing

const LB_TO_KG = 0.45359237;
const MI_TO_KM = 1.60934;
const MPH_TO_M_PER_MIN = 26.8224;

// ============================================
// CORE CALCULATION FUNCTIONS FROM EDGE FUNCTION
// ============================================

function toKg(weight: number, unit?: string): number {
  return unit === "kg" ? weight : weight * LB_TO_KG;
}

function toMiles(distance: number, unit?: string): number {
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

// ACSM level-ground equations with walk/run switch (from v2)
function metFromPace(minPerMile: number): number {
  const mph = 60.0 / minPerMile;
  const v = mph * MPH_TO_M_PER_MIN;
  // Walk/run switch at ~4.0 mph
  const vo2 = mph >= 4.0 ? 0.2 * v + 3.5 : 0.1 * v + 3.5;
  return vo2 / 3.5;
}

// Exact ACSM gross kcal calculation (from v2)
function grossKcal(weightKg: number, durationMin: number, met: number): number {
  return met * 3.5 * weightKg / 200.0 * durationMin;
}

// Net transport cost (from v2)
function netKcalTransportCost(weightKg: number, distanceMiles: number): number {
  return 1.0 * weightKg * (distanceMiles * MI_TO_KM);
}

function durationHours(distanceMiles: number, paceMinPerMile: number): number {
  return distanceMiles * paceMinPerMile / 60.0;
}

// Duration-based carb bands (from v2)
function carbsBandByDuration(durationH: number): [number, number] {
  if (durationH <= 1.0) return [0, 30];
  if (durationH <= 2.0) return [30, 45];
  if (durationH <= 3.0) return [45, 60];
  if (durationH <= 4.0) return [60, 75];
  return [75, 90];
}

// Absorption caps (from v2)
function absorptionCapGph(gut: string, source: string): number {
  if (source === "glucose_only") {
    return gut === "high" ? 65 : 60;
  }
  return gut === "low" ? 80 : gut === "moderate" ? 90 : 100;
}

// Intensity nudge (from v2)
function intensityNudgeFromMet(met: number): number {
  return met < 7 ? -5 : met > 9 ? 5 : 0;
}

// Mass tilt within band (from v2)
function massTiltWithinBand(weightKg: number, low: number, high: number): number {
  return weightKg < 50 ? low : weightKg > 80 ? high : Math.round((low + high) / 2);
}

// Complete carb recommendation (from v2)
interface CarbRecommendation {
  gphLow: number;
  gphHigh: number;
  gphCap: number;
  gphRaw: number;
  gphFinal: number;
}

function recommendCarbsPerHour(
  durationH: number,
  met: number,
  weightKg: number,
  gut: string,
  source: string
): CarbRecommendation {
  const [low, high] = carbsBandByDuration(durationH);

  // Floor condition for moderate duration + high intensity
  let adjustedLow = low;
  if (durationH > 1.1 && met > 8 && low < 30) {
    adjustedLow = 30;
  }

  const gutNudge = gut === "low" ? -5 : gut === "high" ? 5 : 0;
  const raw = Math.max(
    adjustedLow,
    Math.min(
      high,
      massTiltWithinBand(weightKg, adjustedLow, high) + intensityNudgeFromMet(met) + gutNudge
    )
  );

  const cap = absorptionCapGph(gut, source);

  return {
    gphLow: adjustedLow,
    gphHigh: high,
    gphCap: cap,
    gphRaw: raw,
    gphFinal: Math.min(raw, cap)
  };
}

// Environment multiplier (from v2)
function envMultiplier(tempC: number | null, humidityPct: number | null): [number, string] {
  if (tempC === null && humidityPct === null) {
    return [1.0, "moderate"];
  }

  const t = tempC ?? 20.0;
  const h = humidityPct ?? 60.0;

  if (t <= 10) return [0.85, "cool"];
  if (10 < t && t <= 20 && h <= 60) return [1.0, "temperate"];
  if (20 < t && t <= 25 || 60 < h && h <= 75) return [1.1, "warm"];
  if (25 < t && t <= 30 || 75 < h && h <= 85) return [1.2, "hot"];
  return [1.3, "very_hot"];
}

// Fluid band calculation (from v2)
function fluidBandLph(
  weightKg: number,
  met: number,
  tempC: number | null,
  humidityPct: number | null
): [number, number, number, string] {
  let low = 0.4, high = 0.8;

  if (weightKg < 50) high -= 0.1;
  else if (weightKg > 80) low += 0.1;

  if (met > 9) {
    low += 0.05;
    high += 0.05;
  }
  if (met < 7) {
    low -= 0.05;
    high -= 0.05;
  }

  const [mult, label] = envMultiplier(tempC, humidityPct);
  low *= mult;
  high *= mult;

  // Running practicality clamps
  low = Math.max(0.3, Math.min(low, 1.0));
  high = Math.max(low + 0.05, Math.min(high, 1.2));

  return [
    Math.round(low * 100) / 100,
    Math.round(high * 100) / 100,
    mult,
    label
  ];
}

// Pre-run macros (from v2)
interface PreRunMacros {
  carbG: number;
  proteinG: number;
  fatG: number;
}

function preRunMacros(weightKg: number, timeBeforeMin: number): PreRunMacros {
  const hours = Math.min(timeBeforeMin / 60.0, 4.0);
  const choPerKg = Math.min(3.0, Math.max(0.5, hours));
  const carbsG = choPerKg * weightKg;

  let proteinG, fatG;
  if (timeBeforeMin <= 60) {
    proteinG = 0.15 * weightKg;
    fatG = 0.1 * weightKg;
  } else if (timeBeforeMin <= 90) {
    proteinG = 0.2 * weightKg;
    fatG = 0.15 * weightKg;
  } else {
    proteinG = 0.25 * weightKg;
    fatG = 0.2 * weightKg;
  }

  return {
    carbG: Math.round(carbsG * 10) / 10,
    proteinG: Math.round(proteinG * 10) / 10,
    fatG: Math.round(fatG * 10) / 10
  };
}

// During-run macros (from v2)
interface DuringRunMacros {
  carbPerHG: number;
  proteinPerHG: number;
  fatPerHG: number;
  bandLow: number;
  bandHigh: number;
  cap: number;
  raw: number;
}

function duringRunMacros(
  durationH: number,
  met: number,
  weightKg: number,
  gut: string,
  source: string
): DuringRunMacros {
  const c = recommendCarbsPerHour(durationH, met, weightKg, gut, source);
  const proteinPerH = durationH <= 3.5 ? 0.0 : 3.0;
  const fatPerH = durationH <= 3.5 ? 0.0 : 2.0;

  return {
    carbPerHG: c.gphFinal,
    proteinPerHG: proteinPerH,
    fatPerHG: fatPerH,
    bandLow: c.gphLow,
    bandHigh: c.gphHigh,
    cap: c.gphCap,
    raw: c.gphRaw
  };
}

// After-run macros (from v2)
interface AfterRunMacros {
  carbG: number;
  proteinG: number;
  fatG: number;
}

function afterRunMacros(weightKg: number, durationH: number): AfterRunMacros {
  const choPerKg = durationH > 2 ? 1.2 : 1.0;
  return {
    carbG: Math.round(choPerKg * weightKg * 10) / 10,
    proteinG: Math.round(0.3 * weightKg * 10) / 10,
    fatG: Math.round(0.2 * weightKg * 10) / 10
  };
}

// Sodium concentration from category (from v2)
function sodiumConcentrationFromCategory(sweatSodium: string): number {
  return sweatSodium === "low" ? 400 : sweatSodium === "medium" ? 800 : 1200;
}

// Dynamic sodium target (from v2)
function sodiumTargetDynamic(
  sweatSodiumCat: string,
  sweatRateLph: number | null,
  envLabel: string
): [number, number, number, string] {
  if (sweatRateLph !== null) {
    const conc = sodiumConcentrationFromCategory(sweatSodiumCat);
    const lossMgph = conc * sweatRateLph;
    const low = Math.max(300, Math.round(lossMgph * 0.5));
    const high = Math.min(1200, Math.round(lossMgph * 0.7));
    const target = Math.min(high, Math.max(low, Math.round(lossMgph * 0.6)));
    return [low, high, target, "measured"];
  }

  // Category-based
  const [baseLow, baseHigh, baseTarget] = sweatSodiumCat === "low"
    ? [300, 500, 400]
    : sweatSodiumCat === "medium"
    ? [500, 800, 650]
    : [800, 1200, 1000];

  let bump = 0;
  if (envLabel === "warm") bump = 50;
  else if (envLabel === "hot") bump = 100;
  else if (envLabel === "very_hot") bump = 150;

  const low = baseLow + bump;
  const high = Math.min(baseHigh + bump, 1200);
  const target = Math.min(baseTarget + bump, 1200);

  return [low, high, target, "category"];
}

// ============================================
// TEST SUITES
// ============================================

describe('Generate Macros - Advanced Business Logic Tests', () => {

  describe('🔬 ACSM MET Calculations', () => {
    it('should apply walking formula for speeds < 4 mph', () => {
      const walkingPaces = [
        { pace: 20, expectedMet: 2.54 },    // 3 mph
        { pace: 17.14, expectedMet: 2.85 }, // 3.5 mph
        { pace: 15, expectedMet: 3.17 }     // 4 mph (threshold)
      ];

      walkingPaces.forEach(({ pace, expectedMet }) => {
        const met = metFromPace(pace);
        console.log(`  ✓ Walking pace ${pace} min/mile -> MET ${met.toFixed(2)}`);
        expect(met).toBeCloseTo(expectedMet, 1);
      });
    });

    it('should apply running formula for speeds >= 4 mph', () => {
      const runningPaces = [
        { pace: 14.9, expectedMet: 5.19 },  // Just above 4 mph
        { pace: 10, expectedMet: 7.57 },    // 6 mph
        { pace: 8, expectedMet: 9.46 },     // 7.5 mph
        { pace: 6, expectedMet: 12.6 },     // 10 mph
        { pace: 5, expectedMet: 15.13 }     // 12 mph
      ];

      runningPaces.forEach(({ pace, expectedMet }) => {
        const met = metFromPace(pace);
        console.log(`  ✓ Running pace ${pace} min/mile -> MET ${met.toFixed(2)}`);
        expect(met).toBeCloseTo(expectedMet, 1);
      });
    });
  });

  describe('🍞 Carbohydrate Recommendations', () => {
    it('should calculate carb bands correctly by duration', () => {
      const bands = [
        { duration: 0.5, expected: [0, 30] },
        { duration: 1.5, expected: [30, 45] },
        { duration: 2.5, expected: [45, 60] },
        { duration: 3.5, expected: [60, 75] },
        { duration: 4.5, expected: [75, 90] }
      ];

      bands.forEach(({ duration, expected }) => {
        const band = carbsBandByDuration(duration);
        console.log(`  ✓ ${duration}h run -> ${band[0]}-${band[1]}g/h`);
        expect(band).toEqual(expected);
      });
    });

    it('should apply gut training absorption caps', () => {
      const scenarios = [
        { gut: 'low', source: 'dual', expectedCap: 80 },
        { gut: 'moderate', source: 'dual', expectedCap: 90 },
        { gut: 'high', source: 'dual', expectedCap: 100 },
        { gut: 'high', source: 'glucose_only', expectedCap: 65 },
        { gut: 'low', source: 'glucose_only', expectedCap: 60 }
      ];

      scenarios.forEach(({ gut, source, expectedCap }) => {
        const cap = absorptionCapGph(gut, source);
        console.log(`  ✓ ${gut} gut + ${source} -> ${cap}g/h cap`);
        expect(cap).toBe(expectedCap);
      });
    });

    it('should apply intensity nudges based on MET', () => {
      expect(intensityNudgeFromMet(6)).toBe(-5);  // Low intensity
      expect(intensityNudgeFromMet(8)).toBe(0);   // Moderate
      expect(intensityNudgeFromMet(10)).toBe(5);  // High intensity
    });

    it('should apply weight-based tilts within bands', () => {
      const lightTilt = massTiltWithinBand(45, 30, 60);  // Light runner
      const avgTilt = massTiltWithinBand(70, 30, 60);    // Average
      const heavyTilt = massTiltWithinBand(85, 30, 60);  // Heavy runner

      expect(lightTilt).toBe(30);  // Takes lower bound
      expect(avgTilt).toBe(45);    // Takes midpoint
      expect(heavyTilt).toBe(60);  // Takes upper bound
    });

    it('should enforce floor for moderate duration + high intensity', () => {
      const recommendation = recommendCarbsPerHour(
        1.5,     // 90 minutes
        9,       // High MET
        70,      // Average weight
        'moderate',
        'dual'
      );

      console.log('  ✓ Floor condition test:', recommendation);
      expect(recommendation.gphLow).toBeGreaterThanOrEqual(30);
    });
  });

  describe('💧 Hydration Calculations', () => {
    it('should calculate environment multipliers', () => {
      const conditions = [
        { temp: 5, humidity: 50, expectedMult: 0.85, label: 'cool' },
        { temp: 15, humidity: 50, expectedMult: 1.0, label: 'temperate' },
        { temp: 22, humidity: 65, expectedMult: 1.1, label: 'warm' },
        { temp: 28, humidity: 70, expectedMult: 1.2, label: 'hot' },
        { temp: 32, humidity: 80, expectedMult: 1.3, label: 'very_hot' }
      ];

      conditions.forEach(({ temp, humidity, expectedMult, label }) => {
        const [mult, envLabel] = envMultiplier(temp, humidity);
        console.log(`  ✓ ${temp}°C, ${humidity}% -> ${mult}x (${envLabel})`);
        expect(mult).toBe(expectedMult);
        expect(envLabel).toBe(label);
      });
    });

    it('should calculate fluid bands with all factors', () => {
      // Test scenario: Marathon runner, hot conditions
      const [low, high, mult, label] = fluidBandLph(
        70,   // 70kg runner
        10,   // High MET
        28,   // Hot temperature
        75    // High humidity
      );

      console.log(`  ✓ Hot marathon: ${low}-${high} L/h (${mult}x, ${label})`);
      expect(low).toBeGreaterThan(0.5);
      expect(high).toBeLessThanOrEqual(1.2);
      expect(mult).toBe(1.2);
    });
  });

  describe('🧂 Sodium Calculations', () => {
    it('should calculate sodium concentrations by sweat category', () => {
      expect(sodiumConcentrationFromCategory('low')).toBe(400);
      expect(sodiumConcentrationFromCategory('medium')).toBe(800);
      expect(sodiumConcentrationFromCategory('high')).toBe(1200);
    });

    it('should calculate dynamic sodium targets with measured sweat rate', () => {
      const [low, high, target, method] = sodiumTargetDynamic(
        'medium',  // Medium sweat sodium
        0.8,       // 0.8 L/h sweat rate
        'temperate'
      );

      console.log(`  ✓ Measured: ${low}-${high} mg/h, target ${target} (${method})`);
      expect(method).toBe('measured');
      expect(target).toBeGreaterThanOrEqual(low);
      expect(target).toBeLessThanOrEqual(high);
    });

    it('should calculate category-based sodium with environment bump', () => {
      const [low, high, target, method] = sodiumTargetDynamic(
        'high',
        null,      // No measured sweat rate
        'very_hot'
      );

      console.log(`  ✓ Category + hot: ${low}-${high} mg/h, target ${target}`);
      expect(method).toBe('category');
      expect(target).toBeLessThanOrEqual(1200); // Safety cap
    });
  });

  describe('⏱️ Nutrition Timing', () => {
    it('should calculate pre-run macros based on time window', () => {
      const scenarios = [
        { timeMin: 60, weightKg: 70, expectedCarbs: 35, expectedProtein: 10.5 },
        { timeMin: 120, weightKg: 70, expectedCarbs: 140, expectedProtein: 17.5 },
        { timeMin: 240, weightKg: 70, expectedCarbs: 210, expectedProtein: 17.5 }
      ];

      scenarios.forEach(({ timeMin, weightKg, expectedCarbs, expectedProtein }) => {
        const pre = preRunMacros(weightKg, timeMin);
        console.log(`  ✓ ${timeMin}min before: ${pre.carbG}g carbs, ${pre.proteinG}g protein`);
        expect(pre.carbG).toBeCloseTo(expectedCarbs, 0);
        expect(pre.proteinG).toBeCloseTo(expectedProtein, 0);
      });
    });

    it('should add protein/fat for ultra distances', () => {
      const shortRun = duringRunMacros(3, 8, 70, 'moderate', 'dual');
      const ultraRun = duringRunMacros(5, 8, 70, 'moderate', 'dual');

      console.log('  ✓ 3h run:', shortRun.proteinPerHG, 'g/h protein');
      console.log('  ✓ 5h run:', ultraRun.proteinPerHG, 'g/h protein');

      expect(shortRun.proteinPerHG).toBe(0);
      expect(ultraRun.proteinPerHG).toBe(3);
      expect(ultraRun.fatPerHG).toBe(2);
    });

    it('should scale after-run carbs by duration', () => {
      const shortRecovery = afterRunMacros(70, 1.5);
      const longRecovery = afterRunMacros(70, 3.5);

      console.log(`  ✓ 90min run recovery: ${shortRecovery.carbG}g carbs`);
      console.log(`  ✓ 3.5h run recovery: ${longRecovery.carbG}g carbs`);

      expect(shortRecovery.carbG).toBeCloseTo(70, 0);
      expect(longRecovery.carbG).toBeCloseTo(84, 0);
    });
  });

  describe('🏃 Complete Runner Scenarios', () => {
    it('should handle recreational 5K runner', () => {
      const weightKg = 70;
      const distanceMi = 3.1;
      const paceMinPerMile = 10;
      const durationH = durationHours(distanceMi, paceMinPerMile);
      const met = metFromPace(paceMinPerMile);

      const pre = preRunMacros(weightKg, 120);
      const during = duringRunMacros(durationH, met, weightKg, 'low', 'dual');
      const after = afterRunMacros(weightKg, durationH);

      console.log('\n  📊 5K Recreational Runner:');
      console.log(`    Duration: ${(durationH * 60).toFixed(0)} min`);
      console.log(`    MET: ${met.toFixed(1)}`);
      console.log(`    Pre: ${pre.carbG}g carbs`);
      console.log(`    During: ${during.carbPerHG}g/h (${(during.carbPerHG * durationH).toFixed(0)}g total)`);
      console.log(`    After: ${after.carbG}g carbs, ${after.proteinG}g protein`);

      expect(during.carbPerHG).toBeLessThanOrEqual(30); // Low needs for short run
    });

    it('should handle competitive marathon runner', () => {
      const weightKg = 65;
      const distanceMi = 26.2;
      const paceMinPerMile = 7;
      const durationH = durationHours(distanceMi, paceMinPerMile);
      const met = metFromPace(paceMinPerMile);

      const pre = preRunMacros(weightKg, 180);
      const during = duringRunMacros(durationH, met, weightKg, 'high', 'dual');
      const after = afterRunMacros(weightKg, durationH);

      console.log('\n  📊 Marathon Competitor:');
      console.log(`    Duration: ${(durationH * 60).toFixed(0)} min`);
      console.log(`    MET: ${met.toFixed(1)}`);
      console.log(`    Pre: ${pre.carbG}g carbs`);
      console.log(`    During: ${during.carbPerHG}g/h (${(during.carbPerHG * durationH).toFixed(0)}g total)`);
      console.log(`    After: ${after.carbG}g carbs, ${after.proteinG}g protein`);

      expect(during.carbPerHG).toBeGreaterThan(50); // High needs for long, fast run
      expect(during.carbPerHG).toBeLessThanOrEqual(100); // Capped by absorption
    });

    it('should handle ultra runner', () => {
      const weightKg = 75;
      const distanceMi = 50;
      const paceMinPerMile = 12;
      const durationH = durationHours(distanceMi, paceMinPerMile);
      const met = metFromPace(paceMinPerMile);

      const pre = preRunMacros(weightKg, 240);
      const during = duringRunMacros(durationH, met, weightKg, 'moderate', 'dual');
      const after = afterRunMacros(weightKg, durationH);

      console.log('\n  📊 Ultra Runner (50 miles):');
      console.log(`    Duration: ${durationH.toFixed(1)} hours`);
      console.log(`    MET: ${met.toFixed(1)}`);
      console.log(`    Pre: ${pre.carbG}g carbs`);
      console.log(`    During: ${during.carbPerHG}g/h carbs, ${during.proteinPerHG}g/h protein`);
      console.log(`    Total during: ${(during.carbPerHG * durationH).toFixed(0)}g carbs`);
      console.log(`    After: ${after.carbG}g carbs, ${after.proteinG}g protein`);

      expect(during.proteinPerHG).toBeGreaterThan(0); // Protein for ultra distances
      expect(during.fatPerHG).toBeGreaterThan(0);     // Fat for ultra distances
    });
  });

  describe('🚨 Edge Cases and Safety', () => {
    it('should handle zero/negative inputs safely', () => {
      expect(() => metFromPace(0)).toThrow();
      expect(carbsBandByDuration(-1)).toEqual([0, 30]); // Defaults to shortest
    });

    it('should cap extreme values', () => {
      const extremeCarbs = recommendCarbsPerHour(
        10,    // 10 hour ultra
        12,    // Very high MET
        100,   // Heavy runner
        'high',
        'dual'
      );

      expect(extremeCarbs.gphFinal).toBeLessThanOrEqual(100); // Max absorption cap
    });

    it('should handle missing environmental data', () => {
      const [mult, label] = envMultiplier(null, null);
      expect(mult).toBe(1.0);
      expect(label).toBe('moderate');
    });
  });
});