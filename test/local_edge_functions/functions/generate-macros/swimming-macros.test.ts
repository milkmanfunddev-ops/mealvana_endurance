/**
 * TDD Tests for Swimming Macro Generation
 * Following the formulas documented in docs/features/cycling_swimming/formulas.md
 */

import { describe, it, expect } from 'vitest';

// Shared functions from generate-macros
function grossKcal(weightKg: number, durationMin: number, met: number): number {
  return met * 3.5 * weightKg / 200.0 * durationMin;
}

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

function preRunHydration(weightKg: number, minutesBefore: number, sweatCat: string, envLabel: string) {
  let mainMlPerKg = minutesBefore >= 150 ? 6.0 : 4.0;
  if (envLabel === "hot" || envLabel === "very_hot") mainMlPerKg += 1.0;
  const mainMl = mainMlPerKg * weightKg;
  const topoffMl = envLabel === "hot" || envLabel === "very_hot" ? 300.0 : minutesBefore >= 45 ? 250.0 : 150.0;
  let preNa = sweatCat === "low" ? 300 : sweatCat === "medium" ? 450 : 600;
  if (envLabel === "hot" || envLabel === "very_hot") preNa += 100;
  return {
    mainMl: Math.round(mainMl),
    topoffMl: Math.round(topoffMl),
    sodiumMg: preNa
  };
}

// Swimming-specific functions
function swimmingMETFromPace(paceSecondsper100m: number, poolOrOpenWater: string, waterTempC: number): number {
  let met: number;

  if (paceSecondsper100m >= 180) {
    met = 6.0;
  } else if (paceSecondsper100m >= 150) {
    met = 8.0;
  } else if (paceSecondsper100m >= 120) {
    met = 10.0;
  } else if (paceSecondsper100m >= 90) {
    met = 11.0;
  } else {
    met = 13.0;
  }

  if (poolOrOpenWater === 'open_water') {
    met *= 1.15;
  }

  if (waterTempC < 20) {
    met *= 1.1;
  } else if (waterTempC > 28) {
    met *= 0.95;
  }

  return Math.round(met * 10) / 10;
}

function swimmingMETFromIntensity(intensity: string): number {
  const intensityMETs: Record<string, number> = {
    zone_1: 6.0,
    zone_2: 8.0,
    zone_3: 10.0,
    zone_4: 12.0,
  };
  return intensityMETs[intensity];
}

function swimmingGrossCalories(weightKg: number, durationMin: number, met: number): number {
  return grossKcal(weightKg, durationMin, met);
}

function swimmingNetCalories(weightKg: number, distanceKm: number): number {
  const costPerKgKm = 3.5;
  return weightKg * distanceKm * costPerKgKm;
}

function swimmingDuration(distanceMeters: number, paceSecondsper100m: number): number {
  const num100mSegments = distanceMeters / 100;
  const totalSeconds = num100mSegments * paceSecondsper100m;
  return totalSeconds / 60;
}

function swimmingDurationHours(distanceMeters: number, paceSecondsper100m: number): number {
  return swimmingDuration(distanceMeters, paceSecondsper100m) / 60;
}

function swimmingPreSwimCarbs(weightKg: number, hoursBeforeSwim: number): number {
  const hoursEffective = Math.min(hoursBeforeSwim, 4.0);

  if (hoursEffective >= 1.0) {
    return hoursEffective * weightKg;
  } else if (hoursEffective >= 0.25) {
    return 0.5 * weightKg;
  } else {
    return 0.25 * weightKg;
  }
}

function swimmingDuringSwimCarbs(durationH: number, poolOrOpenWater: string, gutTraining: string): number {
  let carbMin: number, carbMax: number;

  if (durationH <= 1.0) {
    carbMin = 0;
    carbMax = 0;
  } else if (durationH <= 1.5) {
    carbMin = 0;
    carbMax = 30;
  } else if (durationH <= 2.5) {
    carbMin = 30;
    carbMax = 60;
  } else {
    carbMin = 45;
    carbMax = 75;
  }

  if (poolOrOpenWater === 'open_water' && durationH > 1.5) {
    carbMax += 10;
  }

  let gutMultiplier = 1.0;
  if (gutTraining === 'low') {
    gutMultiplier = 0.85;
  } else if (gutTraining === 'high') {
    gutMultiplier = 1.1;
  }

  const baseTarget = (carbMin + carbMax) / 2;
  const adjusted = baseTarget * gutMultiplier;

  const maxAbsorption = 60;

  return Math.min(Math.round(adjusted), maxAbsorption);
}

function swimmingPostSwimCarbs(weightKg: number, durationH: number): number {
  const carbPerKg = durationH > 2.0 ? 1.2 : 1.0;
  return carbPerKg * weightKg;
}

function swimmingPostSwimProtein(weightKg: number): number {
  return 0.3 * weightKg;
}

function swimmingDuringSwimProtein(durationH: number): number {
  return durationH > 3.5 ? 3.0 : 0.0;
}

function swimmingHydrationRate(
  weightKg: number,
  met: number,
  waterTempC: number,
  poolDeckTempC: number | null,
  poolDeckHumidityPct: number | null
): number {
  let baseLph = 0.45;

  if (weightKg < 50) {
    baseLph = 0.35;
  } else if (weightKg > 80) {
    baseLph = 0.55;
  }

  if (met >= 11) {
    baseLph += 0.1;
  }

  if (waterTempC > 28) {
    baseLph *= 1.2;
  } else if (waterTempC < 20) {
    baseLph *= 0.8;
  }

  if (poolDeckTempC !== null && poolDeckHumidityPct !== null) {
    const [deckEnvMultiplier] = envMultiplier(poolDeckTempC, poolDeckHumidityPct);
    baseLph *= deckEnvMultiplier;
  }

  return Math.min(baseLph, 0.8);
}

function swimmingSodiumRate(durationH: number, sweatSodiumCat: string, waterTempC: number): number {
  let sodiumMgph = 400;

  if (sweatSodiumCat === 'low') {
    sodiumMgph = 300;
  } else if (sweatSodiumCat === 'medium') {
    sodiumMgph = 500;
  } else if (sweatSodiumCat === 'high') {
    sodiumMgph = 700;
  }

  if (waterTempC > 28) {
    sodiumMgph += 50;
  } else if (waterTempC < 20) {
    sodiumMgph -= 50;
  }

  return Math.min(sodiumMgph, 800);
}

function calculateSwimmingMacros(input: any): any {
  const durationMin = swimmingDuration(input.distanceMeters, input.paceSecondsper100m);
  const durationH = durationMin / 60;
  const distanceKm = input.distanceMeters / 1000;

  const finalMET = swimmingMETFromPace(input.paceSecondsper100m, input.poolOrOpenWater, input.waterTempC);
  const caloriesGross = swimmingGrossCalories(input.weightKg, durationMin, finalMET);
  const caloriesNet = swimmingNetCalories(input.weightKg, distanceKm);

  const hoursBeforeSwim = input.timeBeforeMinutes / 60.0;
  const preCarbs = swimmingPreSwimCarbs(input.weightKg, hoursBeforeSwim);
  const duringCarbsPerH = swimmingDuringSwimCarbs(durationH, input.poolOrOpenWater, input.gutTraining);
  const duringCarbsTotal = duringCarbsPerH * durationH;
  const postCarbs = swimmingPostSwimCarbs(input.weightKg, durationH);

  const preProtein = 0.2 * input.weightKg;
  const duringProtein = swimmingDuringSwimProtein(durationH);
  const postProtein = swimmingPostSwimProtein(input.weightKg);

  const preFat = hoursBeforeSwim > 2.0 ? 0.15 * input.weightKg : 0.1 * input.weightKg;

  const [envMult, envLabel] = envMultiplier(input.poolDeckTempC, input.poolDeckHumidityPct);
  const preWater = preRunHydration(input.weightKg, input.timeBeforeMinutes, input.sweatSodiumCat, envLabel);
  const duringWaterPerH = swimmingHydrationRate(
    input.weightKg,
    finalMET,
    input.waterTempC,
    input.poolDeckTempC,
    input.poolDeckHumidityPct
  );
  const duringWaterTotal = duringWaterPerH * 1000 * durationH;

  const preSodium = preWater.sodiumMg;
  const duringSodiumPerH = swimmingSodiumRate(durationH, input.sweatSodiumCat, input.waterTempC);
  const duringSodiumTotal = duringSodiumPerH * durationH;

  return {
    duration_min: Math.round(durationMin * 100) / 100,
    duration_h: Math.round(durationH * 10000) / 10000,
    pace_per_100m_seconds: input.paceSecondsper100m,
    distance_meters: input.distanceMeters,
    distance_km: Math.round(distanceKm * 1000) / 1000,
    calories_net_kcal: Math.round(caloriesNet),
    calories_gross_kcal: Math.round(caloriesGross),
    MET: Math.round(finalMET * 100) / 100,
    pre_swim_carbs_g: Math.round(preCarbs),
    pre_swim_protein_g: Math.round(preProtein),
    pre_swim_fat_g: Math.round(preFat * 10) / 10,
    during_swim_carbs_per_h: Math.round(duringCarbsPerH),
    during_swim_carbs_total: Math.round(duringCarbsTotal),
    during_swim_protein_per_h: duringProtein,
    post_swim_carbs_g: Math.round(postCarbs),
    post_swim_protein_g: Math.round(postProtein),
    pre_swim_water_ml: preWater.mainMl + preWater.topoffMl,
    during_swim_water_per_h_ml: Math.round(duringWaterPerH * 1000),
    during_swim_water_total_ml: Math.round(duringWaterTotal),
    pre_swim_sodium_mg: preSodium,
    during_swim_sodium_per_h_mg: duringSodiumPerH,
    during_swim_sodium_total_mg: Math.round(duringSodiumTotal),
  };
}

describe('Swimming Macro Generation - TDD', () => {
  describe('MET Calculation from Pace', () => {
    it('should calculate MET for very slow pace (>3:00 per 100m)', () => {
      // Formula: ≥180 sec = 6 METs (pool)
      const paceSecondsper100m = 180;
      const poolOrOpenWater = 'pool';
      const waterTempC = 24;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBe(6.0);
    });

    it('should calculate MET for slow pace (2:30-3:00 per 100m)', () => {
      // Formula: 150-180 sec = 8 METs
      const paceSecondsper100m = 165;
      const poolOrOpenWater = 'pool';
      const waterTempC = 24;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBe(8.0);
    });

    it('should calculate MET for moderate pace (2:00-2:30 per 100m)', () => {
      // Formula: 120-150 sec = 10 METs
      const paceSecondsper100m = 135;
      const poolOrOpenWater = 'pool';
      const waterTempC = 24;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBe(10.0);
    });

    it('should calculate MET for fast pace (1:30-2:00 per 100m)', () => {
      // Formula: 90-120 sec = 11 METs
      const paceSecondsper100m = 105;
      const poolOrOpenWater = 'pool';
      const waterTempC = 24;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBe(11.0);
    });

    it('should calculate MET for very fast pace (<1:30 per 100m)', () => {
      // Formula: <90 sec = 13 METs
      const paceSecondsper100m = 75;
      const poolOrOpenWater = 'pool';
      const waterTempC = 24;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBe(13.0);
    });

    it('should apply 15% increase for open water', () => {
      // Formula: open water multiplier = 1.15
      const paceSecondsper100m = 120; // Base MET = 10
      const poolOrOpenWater = 'open_water';
      const waterTempC = 24;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBeCloseTo(11.5, 1); // 10 * 1.15
    });

    it('should apply 10% increase for cold water (<20C)', () => {
      // Formula: cold water (< 20C) = 1.1x multiplier
      const paceSecondsper100m = 120; // Base MET = 10
      const poolOrOpenWater = 'pool';
      const waterTempC = 18;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBeCloseTo(11.0, 1); // 10 * 1.1
    });

    it('should apply 5% decrease for warm water (>28C)', () => {
      // Formula: warm water (> 28C) = 0.95x multiplier
      const paceSecondsper100m = 120; // Base MET = 10
      const poolOrOpenWater = 'pool';
      const waterTempC = 30;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBeCloseTo(9.5, 1); // 10 * 0.95
    });

    it('should apply both open water and cold water adjustments', () => {
      // Formula: 10 METs * 1.15 (open water) * 1.1 (cold) = 12.65
      const paceSecondsper100m = 120;
      const poolOrOpenWater = 'open_water';
      const waterTempC = 18;

      const met = swimmingMETFromPace(paceSecondsper100m, poolOrOpenWater, waterTempC);
      expect(met).toBeCloseTo(12.7, 1); // 10 * 1.15 * 1.1 ≈ 12.65
    });
  });

  describe('MET from Intensity Zone', () => {
    it('should return 6 METs for zone 1 (easy/recovery)', () => {
      const met = swimmingMETFromIntensity('zone_1');
      expect(met).toBe(6.0);
    });

    it('should return 8 METs for zone 2 (moderate)', () => {
      const met = swimmingMETFromIntensity('zone_2');
      expect(met).toBe(8.0);
    });

    it('should return 10 METs for zone 3 (hard)', () => {
      const met = swimmingMETFromIntensity('zone_3');
      expect(met).toBe(10.0);
    });

    it('should return 12 METs for zone 4 (very hard)', () => {
      const met = swimmingMETFromIntensity('zone_4');
      expect(met).toBe(12.0);
    });
  });

  describe('Energy Expenditure', () => {
    it('should calculate gross calories for moderate swim', () => {
      // 70kg swimmer, 60 min, 10 METs
      // Formula: MET × 3.5 × body weight (kg) / 200 × duration (min)
      // 10 × 3.5 × 70 / 200 × 60 = 735 kcal
      const weightKg = 70;
      const durationMin = 60;
      const met = 10;

      const calories = swimmingGrossCalories(weightKg, durationMin, met);
      expect(calories).toBeCloseTo(735, 0);
    });

    it('should calculate net calories with high energy cost', () => {
      // 70kg swimmer, 3km
      // Formula: 3.5 kcal/kg/km (3-4x higher than running!)
      // 70 × 3 × 3.5 = 735 kcal
      const weightKg = 70;
      const distanceKm = 3;

      const calories = swimmingNetCalories(weightKg, distanceKm);
      expect(calories).toBeCloseTo(735, 0);
    });
  });

  describe('Duration Calculation', () => {
    it('should calculate duration for given distance and pace', () => {
      // 1500m at 2:00/100m = 15 segments * 120 sec = 1800 sec = 30 min
      const distanceMeters = 1500;
      const paceSecondsper100m = 120;

      const durationMin = swimmingDuration(distanceMeters, paceSecondsper100m);
      expect(durationMin).toBeCloseTo(30, 1);
    });

    it('should convert duration to hours', () => {
      const distanceMeters = 3000;
      const paceSecondsper100m = 120;

      const durationH = swimmingDurationHours(distanceMeters, paceSecondsper100m);
      expect(durationH).toBeCloseTo(1.0, 2);
    });
  });

  describe('Carbohydrate Requirements', () => {
    describe('Pre-Swim Carbs', () => {
      it('should calculate carbs for 2-hour window', () => {
        // 70kg swimmer, 2 hours before
        // Formula: 1 g/kg per hour (capped at 4 g/kg)
        // 2 × 70 = 140g
        const weightKg = 70;
        const hoursBeforeSwim = 2.0;

        const carbs = swimmingPreSwimCarbs(weightKg, hoursBeforeSwim);
        expect(carbs).toBeCloseTo(140, 0);
      });

      it('should cap at 4 g/kg for long window', () => {
        const weightKg = 70;
        const hoursBeforeSwim = 5.0;

        const carbs = swimmingPreSwimCarbs(weightKg, hoursBeforeSwim);
        expect(carbs).toBeCloseTo(280, 0);
      });

      it('should use 0.5 g/kg for short window', () => {
        const weightKg = 70;
        const hoursBeforeSwim = 0.5;

        const carbs = swimmingPreSwimCarbs(weightKg, hoursBeforeSwim);
        expect(carbs).toBeCloseTo(35, 0);
      });
    });

    describe('During-Swim Carbs', () => {
      it('should recommend 0 g/h for swims <1 hour', () => {
        const durationH = 0.75;
        const poolOrOpenWater = 'pool';
        const gutTraining = 'moderate';

        const carbsPerH = swimmingDuringSwimCarbs(durationH, poolOrOpenWater, gutTraining);
        expect(carbsPerH).toBe(0);
      });

      it('should recommend 0-30 g/h for 1-1.5 hour swims', () => {
        const durationH = 1.25;
        const poolOrOpenWater = 'pool';
        const gutTraining = 'moderate';

        const carbsPerH = swimmingDuringSwimCarbs(durationH, poolOrOpenWater, gutTraining);
        expect(carbsPerH).toBeGreaterThanOrEqual(0);
        expect(carbsPerH).toBeLessThanOrEqual(30);
      });

      it('should recommend 30-60 g/h for 1.5-2.5 hour swims', () => {
        const durationH = 2.0;
        const poolOrOpenWater = 'pool';
        const gutTraining = 'moderate';

        const carbsPerH = swimmingDuringSwimCarbs(durationH, poolOrOpenWater, gutTraining);
        expect(carbsPerH).toBeGreaterThanOrEqual(30);
        expect(carbsPerH).toBeLessThanOrEqual(60);
      });

      it('should recommend 45-75 g/h for ultra swims (>2.5h)', () => {
        const durationH = 3.5;
        const poolOrOpenWater = 'pool';
        const gutTraining = 'moderate';

        const carbsPerH = swimmingDuringSwimCarbs(durationH, poolOrOpenWater, gutTraining);
        expect(carbsPerH).toBeGreaterThanOrEqual(45);
        expect(carbsPerH).toBeLessThanOrEqual(75);
      });

      it('should add 10 g/h bonus for open water (>1.5h)', () => {
        const durationH = 2.0;
        const gutTraining = 'moderate';

        const poolCarbs = swimmingDuringSwimCarbs(durationH, 'pool', gutTraining);
        const openWaterCarbs = swimmingDuringSwimCarbs(durationH, 'open_water', gutTraining);

        expect(openWaterCarbs).toBeGreaterThan(poolCarbs);
      });

      it('should reduce carbs for low gut training', () => {
        const durationH = 2.0;
        const poolOrOpenWater = 'pool';

        const carbsLow = swimmingDuringSwimCarbs(durationH, poolOrOpenWater, 'low');
        const carbsHigh = swimmingDuringSwimCarbs(durationH, poolOrOpenWater, 'high');

        expect(carbsLow).toBeLessThan(carbsHigh);
      });

      it('should cap at 60 g/h for swimmers (practical limit)', () => {
        const durationH = 4.0;
        const poolOrOpenWater = 'open_water';
        const gutTraining = 'high';

        const carbsPerH = swimmingDuringSwimCarbs(durationH, poolOrOpenWater, gutTraining);
        expect(carbsPerH).toBeLessThanOrEqual(60);
      });
    });

    describe('Post-Swim Carbs', () => {
      it('should recommend 1.0 g/kg for swims <2 hours', () => {
        const weightKg = 70;
        const durationH = 1.5;

        const carbs = swimmingPostSwimCarbs(weightKg, durationH);
        expect(carbs).toBeCloseTo(70, 0);
      });

      it('should recommend 1.2 g/kg for swims >2 hours', () => {
        const weightKg = 70;
        const durationH = 3.0;

        const carbs = swimmingPostSwimCarbs(weightKg, durationH);
        expect(carbs).toBeCloseTo(84, 0);
      });
    });
  });

  describe('Protein Requirements', () => {
    it('should recommend 0.3 g/kg for post-swim recovery', () => {
      const weightKg = 70;

      const protein = swimmingPostSwimProtein(weightKg);
      expect(protein).toBeCloseTo(21, 0);
    });

    it('should recommend 0 g/h during swims <3.5 hours', () => {
      const durationH = 2.0;

      const protein = swimmingDuringSwimProtein(durationH);
      expect(protein).toBe(0);
    });

    it('should recommend 3 g/h for ultra-endurance swims', () => {
      const durationH = 4.0;

      const protein = swimmingDuringSwimProtein(durationH);
      expect(protein).toBe(3.0);
    });
  });

  describe('Hydration Requirements', () => {
    it('should calculate base hydration rate', () => {
      // Swimmers still sweat even in water!
      const weightKg = 70;
      const met = 10;
      const waterTempC = 24;
      const poolDeckTempC = 22;
      const poolDeckHumidityPct = 60;

      const hydrationLph = swimmingHydrationRate(weightKg, met, waterTempC, poolDeckTempC, poolDeckHumidityPct);
      expect(hydrationLph).toBeGreaterThanOrEqual(0.3);
      expect(hydrationLph).toBeLessThanOrEqual(0.8);
    });

    it('should increase hydration for high intensity', () => {
      const weightKg = 70;
      const waterTempC = 24;
      const poolDeckTempC = 22;
      const poolDeckHumidityPct = 60;

      const hydrationLow = swimmingHydrationRate(weightKg, 8, waterTempC, poolDeckTempC, poolDeckHumidityPct);
      const hydrationHigh = swimmingHydrationRate(weightKg, 12, waterTempC, poolDeckTempC, poolDeckHumidityPct);

      expect(hydrationHigh).toBeGreaterThan(hydrationLow);
    });

    it('should increase hydration for warm water (>28C)', () => {
      const weightKg = 70;
      const met = 10;
      const poolDeckTempC = null;
      const poolDeckHumidityPct = null;

      const hydrationCoolWater = swimmingHydrationRate(weightKg, met, 24, poolDeckTempC, poolDeckHumidityPct);
      const hydrationWarmWater = swimmingHydrationRate(weightKg, met, 30, poolDeckTempC, poolDeckHumidityPct);

      expect(hydrationWarmWater).toBeGreaterThan(hydrationCoolWater);
    });

    it('should decrease hydration for cold water (<20C)', () => {
      const weightKg = 70;
      const met = 10;
      const poolDeckTempC = null;
      const poolDeckHumidityPct = null;

      const hydrationNormalWater = swimmingHydrationRate(weightKg, met, 24, poolDeckTempC, poolDeckHumidityPct);
      const hydrationColdWater = swimmingHydrationRate(weightKg, met, 18, poolDeckTempC, poolDeckHumidityPct);

      expect(hydrationColdWater).toBeLessThan(hydrationNormalWater);
    });

    it('should cap hydration at 0.8 L/h', () => {
      const weightKg = 100; // Heavy swimmer
      const met = 13; // Very high intensity
      const waterTempC = 32; // Very warm
      const poolDeckTempC = 35; // Hot deck
      const poolDeckHumidityPct = 90; // Very humid

      const hydration = swimmingHydrationRate(weightKg, met, waterTempC, poolDeckTempC, poolDeckHumidityPct);
      expect(hydration).toBeLessThanOrEqual(0.8);
    });
  });

  describe('Sodium Requirements', () => {
    it('should calculate base sodium for medium sweater', () => {
      const durationH = 2.0;
      const sweatSodiumCat = 'medium';
      const waterTempC = 24;

      const sodium = swimmingSodiumRate(durationH, sweatSodiumCat, waterTempC);
      expect(sodium).toBeCloseTo(500, 50);
    });

    it('should increase sodium for warm water (>28C)', () => {
      const durationH = 2.0;
      const sweatSodiumCat = 'medium';

      const sodiumNormal = swimmingSodiumRate(durationH, sweatSodiumCat, 24);
      const sodiumWarm = swimmingSodiumRate(durationH, sweatSodiumCat, 30);

      expect(sodiumWarm).toBeGreaterThan(sodiumNormal);
    });

    it('should decrease sodium for cold water (<20C)', () => {
      const durationH = 2.0;
      const sweatSodiumCat = 'medium';

      const sodiumNormal = swimmingSodiumRate(durationH, sweatSodiumCat, 24);
      const sodiumCold = swimmingSodiumRate(durationH, sweatSodiumCat, 18);

      expect(sodiumCold).toBeLessThan(sodiumNormal);
    });

    it('should cap sodium at 800 mg/h for swimming', () => {
      const durationH = 2.0;
      const sweatSodiumCat = 'high';
      const waterTempC = 32;

      const sodium = swimmingSodiumRate(durationH, sweatSodiumCat, waterTempC);
      expect(sodium).toBeLessThanOrEqual(800);
    });
  });

  describe('Complete Swimming Macro Calculator', () => {
    it('should calculate complete macros for 3km moderate swim', () => {
      const input = {
        weightKg: 70,
        distanceMeters: 3000,
        paceSecondsper100m: 120, // 2:00/100m
        poolOrOpenWater: 'pool',
        waterTempC: 24,
        poolDeckTempC: 22,
        poolDeckHumidityPct: 60,
        timeBeforeMinutes: 120,
        gutTraining: 'moderate',
        sweatSodiumCat: 'medium',
      };

      const output = calculateSwimmingMacros(input);

      // Duration: 3000m at 2:00/100m = 30 segments * 120s = 3600s = 60min = 1h
      expect(output.duration_min).toBeCloseTo(60, 1);
      expect(output.duration_h).toBeCloseTo(1.0, 2);

      // MET should be around 10 for moderate pace, pool, normal temp
      expect(output.MET).toBeCloseTo(10, 1);

      // Pre-swim carbs: 2 hours × 70kg = 140g
      expect(output.pre_swim_carbs_g).toBeCloseTo(140, 10);

      // During-swim carbs: Very limited for 1h swim
      expect(output.during_swim_carbs_total).toBeLessThanOrEqual(30);

      // Post-swim carbs: 1.0 g/kg × 70kg = 70g (exactly 1h, not >2h)
      expect(output.post_swim_carbs_g).toBeCloseTo(70, 10);

      // Calories should be reasonable (using gross)
      expect(output.calories_gross_kcal).toBeGreaterThan(600);
      expect(output.calories_gross_kcal).toBeLessThan(900);

      // Net calories (3.5 kcal/kg/km): 70 × 3 × 3.5 = 735
      expect(output.calories_net_kcal).toBeCloseTo(735, 20);
    });
  });
});
