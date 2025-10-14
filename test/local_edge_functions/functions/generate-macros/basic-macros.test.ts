import { describe, it, expect } from 'vitest';

// Core constants from generate-macros edge function
const MPH_TO_M_PER_MIN = 26.8224;
const LB_TO_KG = 0.45359237;
const MI_TO_KM = 1.60934;

// Core calculation functions extracted from the actual edge function
function metFromPace(minPerMile: number): number {
  const mph = 60.0 / minPerMile;
  const v = mph * MPH_TO_M_PER_MIN;
  // Walk/run switch at ~4.0 mph
  const vo2 = mph >= 4.0 ? 0.2 * v + 3.5 : 0.1 * v + 3.5;
  return vo2 / 3.5;
}

function grossKcal(weightKg: number, durationMin: number, met: number): number {
  return met * 3.5 * weightKg / 200.0 * durationMin;
}

function netKcalTransportCost(weightKg: number, distanceMiles: number): number {
  return 1.0 * weightKg * (distanceMiles * MI_TO_KM);
}

function toKg(weight: number): number {
  return weight * LB_TO_KG;
}

function durationHours(distanceMiles: number, paceMinPerMile: number): number {
  return distanceMiles * paceMinPerMile / 60.0;
}

describe('Basic Macro Calculations', () => {
  describe('MET Calculations', () => {
    it('should calculate MET correctly for different paces', () => {
      // Test actual values based on the edge function
      expect(metFromPace(15)).toBeCloseTo(7.13, 1); // 4 mph walking
      expect(metFromPace(10)).toBeCloseTo(10.20, 1); // 6 mph running
      expect(metFromPace(8)).toBeCloseTo(12.50, 1);  // 7.5 mph running
      expect(metFromPace(7.5)).toBeCloseTo(13.26, 1); // 8 mph running
    });

    it('should handle walking vs running threshold', () => {
      const walkingMet = metFromPace(15); // 4 mph - at threshold
      const runningMet = metFromPace(14.9); // slightly above 4 mph

      expect(walkingMet).toBeGreaterThan(0);
      expect(runningMet).toBeGreaterThan(walkingMet);
    });
  });

  describe('Calorie Calculations', () => {
    it('should calculate gross calories correctly', () => {
      const weightKg = toKg(150); // 68.04 kg
      const durationMin = 30;
      const met = 10.0;

      const calories = grossKcal(weightKg, durationMin, met);
      expect(calories).toBeCloseTo(357.2, 1);
    });

    it('should calculate net transport cost correctly', () => {
      const weightKg = toKg(150); // 68.04 kg
      const distanceMiles = 10;

      const netCals = netKcalTransportCost(weightKg, distanceMiles);
      expect(netCals).toBeCloseTo(1095, 0);
    });
  });

  describe('Integration Test - Simple 5K', () => {
    it('should calculate complete metrics for a 5K run', () => {
      const params = {
        distance_miles: 3.1,
        pace_min_per_mile: 10, // 6 mph
        weight_lbs: 150,
        temperature_f: 65
      };

      const weightKg = toKg(params.weight_lbs);
      const durationH = durationHours(params.distance_miles, params.pace_min_per_mile);
      const durationMin = durationH * 60;
      const met = metFromPace(params.pace_min_per_mile);

      const calories = grossKcal(weightKg, durationMin, met);
      const netCals = netKcalTransportCost(weightKg, params.distance_miles);

      // Basic assertions
      expect(met).toBeCloseTo(10.20, 1);
      expect(durationH).toBeCloseTo(0.52, 2); // 31 minutes
      expect(calories).toBeCloseTo(376, 0);
      expect(netCals).toBeCloseTo(339, 0);
    });
  });

  describe('Edge Cases', () => {
    it('should handle very slow paces (walking)', () => {
      const slowMet = metFromPace(20); // 3 mph walking
      expect(slowMet).toBeGreaterThan(1);
      expect(slowMet).toBeLessThan(10);
    });

    it('should handle very fast paces', () => {
      const fastMet = metFromPace(5); // 12 mph running
      expect(fastMet).toBeGreaterThan(10);
      expect(fastMet).toBeLessThan(30);
    });

    it('should handle minimum weight', () => {
      const lightWeightKg = toKg(100);
      const calories = grossKcal(lightWeightKg, 30, 10);
      expect(calories).toBeGreaterThan(0);
    });

    it('should handle maximum weight', () => {
      const heavyWeightKg = toKg(250);
      const calories = grossKcal(heavyWeightKg, 30, 10);
      expect(calories).toBeGreaterThan(0);
    });
  });
});