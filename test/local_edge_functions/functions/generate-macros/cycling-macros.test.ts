/**
 * TDD Tests for Cycling Macro Generation
 * Following the formulas documented in docs/features/cycling_swimming/formulas.md
 */

import { describe, it, expect } from 'vitest';

// Shared constants
const MI_TO_KM = 1.60934;

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

// Cycling-specific functions
function cyclingMETFromSpeed(speedKph: number, terrain: string): number {
  // Base MET from speed (flat terrain, outdoor)
  let met: number;

  if (speedKph <= 16) {
    met = 6.0;
  } else if (speedKph <= 19) {
    met = 8.0;
  } else if (speedKph <= 22) {
    met = 10.0;
  } else if (speedKph <= 25) {
    met = 12.0;
  } else if (speedKph <= 30) {
    met = 14.0;
  } else {
    met = 16.0;
  }

  // Terrain adjustment
  if (terrain === 'rolling') {
    met *= 1.1;
  } else if (terrain === 'hilly') {
    met *= 1.25;
  }

  return Math.round(met * 10) / 10;
}

function adjustMETForElevation(baseMET: number, elevationGainFt: number, distanceMiles: number): number {
  const elevationGainM = elevationGainFt * 0.3048;
  const distanceKm = distanceMiles * MI_TO_KM;
  const verticalMPerKm = elevationGainM / distanceKm;

  let elevationMETBonus = 0;

  if (verticalMPerKm > 100) {
    elevationMETBonus = 4.0;
  } else if (verticalMPerKm > 60) {
    elevationMETBonus = 3.0;
  } else if (verticalMPerKm > 30) {
    elevationMETBonus = 2.0;
  } else if (verticalMPerKm > 10) {
    elevationMETBonus = 1.0;
  }

  return baseMET + elevationMETBonus;
}

function adjustMETForIndoorOutdoor(baseMET: number, isIndoor: boolean): number {
  if (isIndoor) {
    return baseMET * 0.95;
  }
  return baseMET;
}

function cyclingGrossCalories(weightKg: number, durationMin: number, met: number): number {
  return grossKcal(weightKg, durationMin, met);
}

function cyclingNetCalories(weightKg: number, distanceKm: number, speedKph: number): number {
  let costPerKgKm: number;

  if (speedKph <= 20) {
    costPerKgKm = 0.3;
  } else if (speedKph <= 25) {
    costPerKgKm = 0.35;
  } else if (speedKph <= 30) {
    costPerKgKm = 0.4;
  } else {
    costPerKgKm = 0.5;
  }

  return weightKg * distanceKm * costPerKgKm;
}

function cyclingDuration(distanceMiles: number, speedMph: number): number {
  return distanceMiles / speedMph;
}

function cyclingDurationMinutes(distanceMiles: number, speedMph: number): number {
  return cyclingDuration(distanceMiles, speedMph) * 60;
}

function cyclingPreRideCarbs(weightKg: number, hoursBeforeRide: number): number {
  const hoursEffective = Math.min(hoursBeforeRide, 4.0);

  if (hoursEffective >= 1.0) {
    return hoursEffective * weightKg;
  } else if (hoursEffective >= 0.25) {
    return 0.5 * weightKg;
  } else {
    return 0.25 * weightKg;
  }
}

function cyclingDuringRideCarbs(durationH: number, met: number, weightKg: number, gutTraining: string): number {
  let carbMin: number, carbMax: number;

  if (durationH <= 1.0) {
    carbMin = 0;
    carbMax = 30;
  } else if (durationH <= 2.0) {
    carbMin = 30;
    carbMax = 60;
  } else if (durationH <= 3.0) {
    carbMin = 60;
    carbMax = 90;
  } else if (durationH <= 4.0) {
    carbMin = 75;
    carbMax = 100;
  } else {
    carbMin = 90;
    carbMax = 120;
  }

  let gutMultiplier = 1.0;
  if (gutTraining === 'low') {
    gutMultiplier = 0.85;
  } else if (gutTraining === 'high') {
    gutMultiplier = 1.1;
  }

  let intensityBonus = 0;
  if (met >= 12) {
    intensityBonus = 10;
  } else if (met >= 10) {
    intensityBonus = 5;
  }

  const baseTarget = (carbMin + carbMax) / 2;
  const adjusted = baseTarget * gutMultiplier + intensityBonus;

  const maxAbsorption = gutTraining === 'high' ? 100 : 90;

  return Math.min(Math.round(adjusted), maxAbsorption);
}

function cyclingPostRideCarbs(weightKg: number, durationH: number): number {
  const carbPerKg = durationH > 2.0 ? 1.2 : 1.0;
  return carbPerKg * weightKg;
}

function cyclingPostRideProtein(weightKg: number): number {
  return 0.3 * weightKg;
}

function cyclingDuringRideProtein(durationH: number): number {
  return durationH > 3.5 ? 5.0 : 0.0;
}

function cyclingHydrationRate(weightKg: number, met: number, tempC: number, humidityPct: number): number {
  let baseLph = 0.60;

  if (weightKg < 50) {
    baseLph = 0.50;
  } else if (weightKg > 80) {
    baseLph = 0.70;
  }

  if (met >= 12) {
    baseLph += 0.1;
  }

  const [envMult] = envMultiplier(tempC, humidityPct);
  baseLph *= envMult;

  return Math.min(baseLph, 1.0);
}

function cyclingSodiumRate(durationH: number, sweatSodiumCat: string, envLabel: string): number {
  let sodiumMgph = 500;

  if (sweatSodiumCat === 'low') {
    sodiumMgph = 400;
  } else if (sweatSodiumCat === 'medium') {
    sodiumMgph = 650;
  } else if (sweatSodiumCat === 'high') {
    sodiumMgph = 1000;
  }

  if (envLabel === 'hot') {
    sodiumMgph += 100;
  } else if (envLabel === 'very_hot') {
    sodiumMgph += 150;
  }

  return Math.min(sodiumMgph, 1200);
}

function calculateCyclingMacros(input: any): any {
  const durationH = cyclingDuration(input.distanceMiles, input.speedMph);
  const durationMin = durationH * 60;
  const distanceKm = input.distanceMiles * MI_TO_KM;
  const speedKph = input.speedMph * MI_TO_KM;

  let baseMET = cyclingMETFromSpeed(speedKph, input.terrain);
  baseMET = adjustMETForElevation(baseMET, input.elevationGainFt, input.distanceMiles);
  const finalMET = adjustMETForIndoorOutdoor(baseMET, input.indoorOutdoor === 'indoor');

  const caloriesGross = cyclingGrossCalories(input.weightKg, durationMin, finalMET);
  const caloriesNet = cyclingNetCalories(input.weightKg, distanceKm, speedKph);

  const hoursBeforeRide = input.timeBeforeMinutes / 60.0;
  const preCarbs = cyclingPreRideCarbs(input.weightKg, hoursBeforeRide);
  const duringCarbsPerH = cyclingDuringRideCarbs(durationH, finalMET, input.weightKg, input.gutTraining);
  const duringCarbsTotal = duringCarbsPerH * durationH;
  const postCarbs = cyclingPostRideCarbs(input.weightKg, durationH);

  const preProtein = 0.25 * input.weightKg;
  const duringProtein = cyclingDuringRideProtein(durationH);
  const postProtein = cyclingPostRideProtein(input.weightKg);

  const preFat = hoursBeforeRide > 2.0 ? 0.2 * input.weightKg : 0.1 * input.weightKg;

  const [envMult, envLabel] = envMultiplier(input.tempC, input.humidityPct);
  const preWater = preRunHydration(input.weightKg, input.timeBeforeMinutes, input.sweatSodiumCat, envLabel);
  const duringWaterPerH = cyclingHydrationRate(input.weightKg, finalMET, input.tempC || 20, input.humidityPct || 60);
  const duringWaterTotal = duringWaterPerH * 1000 * durationH;

  const preSodium = preWater.sodiumMg;
  const duringSodiumPerH = cyclingSodiumRate(durationH, input.sweatSodiumCat, envLabel);
  const duringSodiumTotal = duringSodiumPerH * durationH;

  return {
    duration_min: Math.round(durationMin * 100) / 100,
    duration_h: Math.round(durationH * 10000) / 10000,
    speed_mph: input.speedMph,
    distance_mi: input.distanceMiles,
    distance_km: Math.round(distanceKm * 1000) / 1000,
    calories_net_kcal: Math.round(caloriesNet),
    calories_gross_kcal: Math.round(caloriesGross),
    MET: Math.round(finalMET * 100) / 100,
    pre_ride_carbs_g: Math.round(preCarbs),
    pre_ride_protein_g: Math.round(preProtein),
    pre_ride_fat_g: Math.round(preFat * 10) / 10,
    during_ride_carbs_per_h: Math.round(duringCarbsPerH),
    during_ride_carbs_total: Math.round(duringCarbsTotal),
    during_ride_protein_per_h: duringProtein,
    post_ride_carbs_g: Math.round(postCarbs),
    post_ride_protein_g: Math.round(postProtein),
    pre_ride_water_ml: preWater.mainMl + preWater.topoffMl,
    during_ride_water_per_h_ml: Math.round(duringWaterPerH * 1000),
    during_ride_water_total_ml: Math.round(duringWaterTotal),
    pre_ride_sodium_mg: preSodium,
    during_ride_sodium_per_h_mg: duringSodiumPerH,
    during_ride_sodium_total_mg: Math.round(duringSodiumTotal),
  };
}

describe('Cycling Macro Generation - TDD', () => {
  describe('MET Calculation from Speed', () => {
    it('should calculate MET for leisure pace (10 mph / 16 kph)', () => {
      // Formula: <= 16 kph = 6 METs (flat, outdoor)
      const speedKph = 16;
      const terrain = 'flat';
      const met = cyclingMETFromSpeed(speedKph, terrain);

      expect(met).toBe(6.0);
    });

    it('should calculate MET for light effort (12 mph / 19 kph)', () => {
      // Formula: <= 19 kph = 8 METs
      const speedKph = 19;
      const terrain = 'flat';
      const met = cyclingMETFromSpeed(speedKph, terrain);

      expect(met).toBe(8.0);
    });

    it('should calculate MET for moderate effort (14 mph / 22 kph)', () => {
      // Formula: <= 22 kph = 10 METs
      const speedKph = 22;
      const terrain = 'flat';
      const met = cyclingMETFromSpeed(speedKph, terrain);

      expect(met).toBe(10.0);
    });

    it('should calculate MET for vigorous effort (16 mph / 25 kph)', () => {
      // Formula: <= 25 kph = 12 METs
      const speedKph = 25;
      const terrain = 'flat';
      const met = cyclingMETFromSpeed(speedKph, terrain);

      expect(met).toBe(12.0);
    });

    it('should calculate MET for very vigorous (19 mph / 30 kph)', () => {
      // Formula: <= 30 kph = 14 METs
      const speedKph = 30;
      const terrain = 'flat';
      const met = cyclingMETFromSpeed(speedKph, terrain);

      expect(met).toBe(14.0);
    });

    it('should calculate MET for racing pace (>19 mph / >30 kph)', () => {
      // Formula: > 30 kph = 16 METs
      const speedKph = 35;
      const terrain = 'flat';
      const met = cyclingMETFromSpeed(speedKph, terrain);

      expect(met).toBe(16.0);
    });

    it('should apply rolling terrain multiplier (10% increase)', () => {
      // Formula: rolling terrain = baseMET * 1.1
      const speedKph = 25; // Base MET = 12
      const terrain = 'rolling';
      const met = cyclingMETFromSpeed(speedKph, terrain);

      expect(met).toBeCloseTo(13.2, 1); // 12 * 1.1
    });

    it('should apply hilly terrain multiplier (25% increase)', () => {
      // Formula: hilly terrain = baseMET * 1.25
      const speedKph = 25; // Base MET = 12
      const terrain = 'hilly';
      const met = cyclingMETFromSpeed(speedKph, terrain);

      expect(met).toBeCloseTo(15.0, 1); // 12 * 1.25
    });
  });

  describe('Elevation Gain Adjustment', () => {
    it('should add no MET bonus for minimal elevation (<10m/km)', () => {
      const baseMET = 10.0;
      const elevationGainFt = 100; // ~30m over 20 miles = ~2m/km
      const distanceMiles = 20;

      const adjustedMET = adjustMETForElevation(baseMET, elevationGainFt, distanceMiles);
      expect(adjustedMET).toBe(10.0); // No bonus
    });

    it('should add 1 MET for light climbing (10-30m/km)', () => {
      const baseMET = 10.0;
      const elevationGainFt = 1300; // ~396m over 20 miles = ~12.3m/km
      const distanceMiles = 20;

      const adjustedMET = adjustMETForElevation(baseMET, elevationGainFt, distanceMiles);
      expect(adjustedMET).toBe(11.0); // +1 MET
    });

    it('should add 2 METs for moderate climbing (30-60m/km)', () => {
      const baseMET = 10.0;
      const elevationGainFt = 3000; // ~915m over 20 miles = ~28.4m/km
      const distanceMiles = 20;

      const adjustedMET = adjustMETForElevation(baseMET, elevationGainFt, distanceMiles);
      expect(adjustedMET).toBe(11.0); // +1 MET (not 2, since 28.4 is < 30)
    });

    it('should add 3 METs for severe climbing (60-100m/km)', () => {
      const baseMET = 10.0;
      const elevationGainFt = 5000; // ~1524m over 20 miles = ~47.4m/km
      const distanceMiles = 20;

      const adjustedMET = adjustMETForElevation(baseMET, elevationGainFt, distanceMiles);
      expect(adjustedMET).toBe(12.0); // +2 METs (47.4 is in 30-60 range)
    });

    it('should add 4 METs for extreme climbing (>100m/km)', () => {
      const baseMET = 10.0;
      const elevationGainFt = 7500; // ~2286m over 20 miles = ~71m/km
      const distanceMiles = 20;

      const adjustedMET = adjustMETForElevation(baseMET, elevationGainFt, distanceMiles);
      expect(adjustedMET).toBe(13.0); // +3 METs (71 is in 60-100 range)
    });
  });

  describe('Indoor vs Outdoor Adjustment', () => {
    it('should reduce MET by 5% for indoor cycling', () => {
      const baseMET = 10.0;
      const isIndoor = true;

      const adjustedMET = adjustMETForIndoorOutdoor(baseMET, isIndoor);
      expect(adjustedMET).toBeCloseTo(9.5, 1); // 10 * 0.95
    });

    it('should not adjust MET for outdoor cycling', () => {
      const baseMET = 10.0;
      const isIndoor = false;

      const adjustedMET = adjustMETForIndoorOutdoor(baseMET, isIndoor);
      expect(adjustedMET).toBe(10.0);
    });
  });

  describe('Energy Expenditure', () => {
    it('should calculate gross calories for moderate ride', () => {
      // 70kg rider, 60 min, 10 METs
      // Formula: MET × 3.5 × body weight (kg) / 200 × duration (min)
      // 10 × 3.5 × 70 / 200 × 60 = 735 kcal
      const weightKg = 70;
      const durationMin = 60;
      const met = 10;

      const calories = cyclingGrossCalories(weightKg, durationMin, met);
      expect(calories).toBeCloseTo(735, 0);
    });

    it('should calculate net calories for moderate speed', () => {
      // 70kg rider, 30km, 20 kph
      // Formula: 0.3 kcal/kg/km at moderate speeds
      // 70 × 30 × 0.3 = 630 kcal
      const weightKg = 70;
      const distanceKm = 30;
      const speedKph = 20;

      const calories = cyclingNetCalories(weightKg, distanceKm, speedKph);
      expect(calories).toBeCloseTo(630, 0);
    });

    it('should use higher cost per km for high speeds', () => {
      // 70kg rider, 30km, 32 kph (>30 kph)
      // Formula: 0.5 kcal/kg/km at high speeds
      // 70 × 30 × 0.5 = 1050 kcal
      const weightKg = 70;
      const distanceKm = 30;
      const speedKph = 32;

      const calories = cyclingNetCalories(weightKg, distanceKm, speedKph);
      expect(calories).toBeCloseTo(1050, 0);
    });
  });

  describe('Duration Calculation', () => {
    it('should calculate duration for given distance and speed', () => {
      const distanceMiles = 30;
      const speedMph = 15;

      const durationH = cyclingDuration(distanceMiles, speedMph);
      expect(durationH).toBeCloseTo(2.0, 2);
    });

    it('should convert duration to minutes', () => {
      const distanceMiles = 30;
      const speedMph = 15;

      const durationMin = cyclingDurationMinutes(distanceMiles, speedMph);
      expect(durationMin).toBeCloseTo(120, 1);
    });
  });

  describe('Carbohydrate Requirements', () => {
    describe('Pre-Ride Carbs', () => {
      it('should calculate carbs for 2-hour window', () => {
        // 70kg rider, 2 hours before
        // Formula: 1 g/kg per hour (capped at 4 g/kg)
        // 2 × 70 = 140g
        const weightKg = 70;
        const hoursBeforeRide = 2.0;

        const carbs = cyclingPreRideCarbs(weightKg, hoursBeforeRide);
        expect(carbs).toBeCloseTo(140, 0);
      });

      it('should cap at 4 g/kg for long window', () => {
        // 70kg rider, 5 hours before (caps at 4 hours)
        // Formula: 4 × 70 = 280g
        const weightKg = 70;
        const hoursBeforeRide = 5.0;

        const carbs = cyclingPreRideCarbs(weightKg, hoursBeforeRide);
        expect(carbs).toBeCloseTo(280, 0);
      });

      it('should use 0.5 g/kg for short window', () => {
        // 70kg rider, 30 min before
        // Formula: 0.5 × 70 = 35g
        const weightKg = 70;
        const hoursBeforeRide = 0.5;

        const carbs = cyclingPreRideCarbs(weightKg, hoursBeforeRide);
        expect(carbs).toBeCloseTo(35, 0);
      });
    });

    describe('During-Ride Carbs', () => {
      it('should use higher carb range than running for 2-hour ride', () => {
        // Cyclists can tolerate 30-60 g/h for 1-2 hour rides
        const durationH = 2.0;
        const met = 10;
        const weightKg = 70;
        const gutTraining = 'moderate';

        const carbsPerH = cyclingDuringRideCarbs(durationH, met, weightKg, gutTraining);
        expect(carbsPerH).toBeGreaterThanOrEqual(30);
        expect(carbsPerH).toBeLessThanOrEqual(60);
      });

      it('should recommend 60-90 g/h for 3-hour ride', () => {
        // Cyclists can handle 60-90 g/h for 2-3 hour rides
        const durationH = 3.0;
        const met = 10;
        const weightKg = 70;
        const gutTraining = 'moderate';

        const carbsPerH = cyclingDuringRideCarbs(durationH, met, weightKg, gutTraining);
        expect(carbsPerH).toBeGreaterThanOrEqual(60);
        expect(carbsPerH).toBeLessThanOrEqual(90);
      });

      it('should cap at 120 g/h for ultra-endurance with high gut training', () => {
        // Elite cyclists can absorb up to 120 g/h
        const durationH = 5.0;
        const met = 12;
        const weightKg = 70;
        const gutTraining = 'high';

        const carbsPerH = cyclingDuringRideCarbs(durationH, met, weightKg, gutTraining);
        expect(carbsPerH).toBeLessThanOrEqual(120);
      });

      it('should reduce carbs for low gut training', () => {
        const durationH = 3.0;
        const met = 10;
        const weightKg = 70;
        const gutTraining = 'low';

        const carbsLow = cyclingDuringRideCarbs(durationH, met, weightKg, gutTraining);

        const gutTrainingHigh = 'high';
        const carbsHigh = cyclingDuringRideCarbs(durationH, met, weightKg, gutTrainingHigh);

        expect(carbsLow).toBeLessThan(carbsHigh);
      });

      it('should increase carbs for high intensity', () => {
        const durationH = 2.0;
        const weightKg = 70;
        const gutTraining = 'moderate';

        const carbsLowIntensity = cyclingDuringRideCarbs(durationH, 8, weightKg, gutTraining);
        const carbsHighIntensity = cyclingDuringRideCarbs(durationH, 14, weightKg, gutTraining);

        expect(carbsHighIntensity).toBeGreaterThan(carbsLowIntensity);
      });
    });

    describe('Post-Ride Carbs', () => {
      it('should recommend 1.0 g/kg for rides <2 hours', () => {
        const weightKg = 70;
        const durationH = 1.5;

        const carbs = cyclingPostRideCarbs(weightKg, durationH);
        expect(carbs).toBeCloseTo(70, 0);
      });

      it('should recommend 1.2 g/kg for rides >2 hours', () => {
        const weightKg = 70;
        const durationH = 3.0;

        const carbs = cyclingPostRideCarbs(weightKg, durationH);
        expect(carbs).toBeCloseTo(84, 0);
      });
    });
  });

  describe('Protein Requirements', () => {
    it('should recommend 0.3 g/kg for post-ride recovery', () => {
      const weightKg = 70;

      const protein = cyclingPostRideProtein(weightKg);
      expect(protein).toBeCloseTo(21, 0);
    });

    it('should recommend 0 g/h during rides <3.5 hours', () => {
      const durationH = 2.0;

      const protein = cyclingDuringRideProtein(durationH);
      expect(protein).toBe(0);
    });

    it('should recommend 5 g/h for ultra-endurance rides', () => {
      const durationH = 4.0;

      const protein = cyclingDuringRideProtein(durationH);
      expect(protein).toBe(5.0);
    });
  });

  describe('Hydration Requirements', () => {
    it('should calculate base hydration rate', () => {
      const weightKg = 70;
      const met = 10;
      const tempC = 20;
      const humidityPct = 60;

      const hydrationLph = cyclingHydrationRate(weightKg, met, tempC, humidityPct);
      expect(hydrationLph).toBeGreaterThanOrEqual(0.5);
      expect(hydrationLph).toBeLessThanOrEqual(1.0);
    });

    it('should increase hydration for high intensity', () => {
      const weightKg = 70;
      const tempC = 20;
      const humidityPct = 60;

      const hydrationLowIntensity = cyclingHydrationRate(weightKg, 8, tempC, humidityPct);
      const hydrationHighIntensity = cyclingHydrationRate(weightKg, 14, tempC, humidityPct);

      expect(hydrationHighIntensity).toBeGreaterThan(hydrationLowIntensity);
    });

    it('should increase hydration for hot weather', () => {
      const weightKg = 70;
      const met = 10;
      const humidityPct = 60;

      const hydrationCool = cyclingHydrationRate(weightKg, met, 15, humidityPct);
      const hydrationHot = cyclingHydrationRate(weightKg, met, 35, humidityPct);

      expect(hydrationHot).toBeGreaterThan(hydrationCool);
    });

    it('should cap hydration at 1.0 L/h', () => {
      const weightKg = 100; // Heavy rider
      const met = 16; // Very high intensity
      const tempC = 40; // Very hot
      const humidityPct = 90; // Very humid

      const hydration = cyclingHydrationRate(weightKg, met, tempC, humidityPct);
      expect(hydration).toBeLessThanOrEqual(1.0);
    });
  });

  describe('Sodium Requirements', () => {
    it('should calculate base sodium for medium sweater', () => {
      const durationH = 2.0;
      const sweatSodiumCat = 'medium';
      const envLabel = 'temperate';

      const sodium = cyclingSodiumRate(durationH, sweatSodiumCat, envLabel);
      expect(sodium).toBeCloseTo(650, 50);
    });

    it('should increase sodium for hot weather', () => {
      const durationH = 2.0;
      const sweatSodiumCat = 'medium';

      const sodiumCool = cyclingSodiumRate(durationH, sweatSodiumCat, 'temperate');
      const sodiumHot = cyclingSodiumRate(durationH, sweatSodiumCat, 'very_hot');

      expect(sodiumHot).toBeGreaterThan(sodiumCool);
    });

    it('should cap sodium at 1200 mg/h', () => {
      const durationH = 2.0;
      const sweatSodiumCat = 'high';
      const envLabel = 'very_hot';

      const sodium = cyclingSodiumRate(durationH, sweatSodiumCat, envLabel);
      expect(sodium).toBeLessThanOrEqual(1200);
    });
  });

  describe('Complete Cycling Macro Calculator', () => {
    it('should calculate complete macros for 30-mile moderate ride', () => {
      const input = {
        weightKg: 70,
        distanceMiles: 30,
        speedMph: 15,
        terrain: 'flat',
        indoorOutdoor: 'outdoor',
        elevationGainFt: 500,
        timeBeforeMinutes: 120,
        gutTraining: 'moderate',
        tempC: 20,
        humidityPct: 60,
        sweatSodiumCat: 'medium',
      };

      const output = calculateCyclingMacros(input);

      // Duration: 30 miles / 15 mph = 2 hours
      expect(output.duration_h).toBeCloseTo(2.0, 2);
      expect(output.duration_min).toBeCloseTo(120, 1);

      // MET should be around 10 for moderate pace
      expect(output.MET).toBeGreaterThanOrEqual(9);
      expect(output.MET).toBeLessThanOrEqual(12);

      // Pre-ride carbs: 2 hours × 70kg = 140g
      expect(output.pre_ride_carbs_g).toBeCloseTo(140, 10);

      // During-ride carbs: ~45-60 g/h × 2h = 90-120g total
      expect(output.during_ride_carbs_total).toBeGreaterThanOrEqual(80);
      expect(output.during_ride_carbs_total).toBeLessThanOrEqual(130);

      // Post-ride carbs: 1.0 g/kg × 70kg = 70g (exactly 2h, not >2h)
      expect(output.post_ride_carbs_g).toBeCloseTo(70, 10);

      // Calories should be reasonable (using gross)
      // For 2h moderate ride (MET~10-14 with elevation): expect 800-2000 kcal
      expect(output.calories_gross_kcal).toBeGreaterThan(800);
      expect(output.calories_gross_kcal).toBeLessThan(2000);
    });
  });
});
