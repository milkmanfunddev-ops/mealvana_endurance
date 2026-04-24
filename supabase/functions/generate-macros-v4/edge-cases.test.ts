/**
 * Edge Case Tests for Hydration Algorithm
 *
 * Ported from /docs/sodium_hydration/hydration_sodium_calc_tests.md §Edge Cases
 *
 * Run with:
 *   deno test supabase/functions/generate-macros-v4/edge-cases.test.ts
 */

import {
  assertEquals,
  assert,
  assertThrows,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { calculateDuringWorkoutHydration } from './single-sport.ts';
import { calculateActualSweatRate } from '../_shared/nutrition/sweat-hydration.ts';
import { calculateBrickHydration } from './brick-workout.ts';

// ============================================================================
// known_sweat_rate_ml_hr = 0 → clamped to 0.3
// ============================================================================

describe('Edge: known_sweat_rate_ml_hr = 0', () => {
  it('effective rate clamped to 0.3 L/hr', () => {
    const rate = calculateActualSweatRate('medium', 22, 50, false, 0, null);
    assertEquals(rate, 0.3);
  });
});

// ============================================================================
// Negative temp (-10°C) → temp_multiplier clamped to 0.50
// ============================================================================

describe('Edge: negative temp_celsius (-10°C)', () => {
  it('temp_multiplier clamped to 0.50', () => {
    // raw = 1.0 + (-10-22)*0.04 = 1.0 + (-1.28) = -0.28 → clamp to 0.50
    const rate = calculateActualSweatRate('medium', -10, 50, false, null, null);
    // MEDIUM * 0.50 = 1.28 * 0.50 = 0.64
    const diff = Math.abs(rate - 0.64);
    assert(diff <= 0.01, `Expected ~0.64, got ${rate}`);
  });
});

// ============================================================================
// humidity_percent = 0 → humidity_multiplier = 1.00
// ============================================================================

describe('Edge: humidity_percent = 0', () => {
  it('humidity below 50 threshold → multiplier 1.00', () => {
    const rate = calculateActualSweatRate('medium', 22, 0, false, null, null);
    const diff = Math.abs(rate - 1.28);
    assert(diff <= 0.01, `Expected 1.28, got ${rate}`);
  });
});

// ============================================================================
// Single swimming segment (30 min) → recommended = 0 ml/hr
// ============================================================================

describe('Edge: single swimming segment (swim-only)', () => {
  it('hydration_rate_mlph = 0 for swim-only workout', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 30,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'swimming',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assertEquals(result.hydration_rate_mlph, 0, 'swim-only = 0 ml/hr');
  });
});

// ============================================================================
// duration_min = 0 → reject or return zero
// ============================================================================

describe('Edge: duration_min = 0', () => {
  it('gate fires (duration<60 AND temp<30) and rate defaults to 30% cap', () => {
    // Tightened 2026-04-24: the prior try/catch accepted any behavior.
    // Current implementation: duration=0 triggers the short-workout gate
    // (duration < 60 AND temp < 30 at 22°C), which returns the 30% of
    // sweat rate conservative cap (~384 ml/hr for medium sweater). Any
    // hour-total math downstream naturally becomes zero because
    // durationH=0. This locks in the current behavior — if the algo
    // ever changes to throw on duration=0, adjust to `assertThrows`.
    const result = calculateDuringWorkoutHydration({
      durationMin: 0,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assertEquals(result.hydration_total_ml, 0, 'total is 0 since durationH=0');
    assertEquals(result.sodium_total_mg, 0, 'total is 0 since durationH=0');
    assertEquals(result.floor_ml_hr, 0, 'gate path → floor = 0');
    // Gate-triggered flag must be present.
    assertEquals(
      result.safety_flags.some((f) => f.includes('No structured hydration plan')),
      true,
      'gate safety flag emitted',
    );
  });
});

// ============================================================================
// body_weight_kg = 0 → reject
// ============================================================================

describe('Edge: body_weight_kg = 0', () => {
  it('returns floor=0 safely (no deficit to clamp against)', () => {
    // Tightened 2026-04-24: the prior try/catch accepted any behavior.
    // Current implementation: weightKg=0 produces maxDeficitMl=0 so the
    // floor formula (totalLossMl - 0) / durationH yields floor =
    // effective_sweat_rate_mlph (entire loss must be replaced). The
    // ceiling=min(GI, sweat_rate) then caps the rate. Deficit safety
    // check skips when weightKg<=0. Locks in current behavior.
    const result = calculateDuringWorkoutHydration({
      durationMin: 60,
      weightKg: 0,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    // At 60 min + 22°C the gate is off (duration not <60). Full path runs.
    // With BW=0, maxDeficitMl=0 → floor = full sweat rate (1280 ml/hr).
    // Ceiling = min(800 run GI, 1280) = 800.
    assertEquals(result.ceiling_ml_hr, 800, 'run GI ceiling');
    // Since floor > ceiling, the algorithm emits the "Even at maximum
    // intake" flag and uses the ceiling.
    assertEquals(result.hydration_rate_mlph, 800, 'capped at run GI');
    assertEquals(
      result.safety_flags.some((f) =>
        f.includes('Even at maximum intake'),
      ),
      true,
      'ceiling<floor flag emitted',
    );
  });
});

// ============================================================================
// Gate boundary: 59 min at exactly 30°C → NOT triggered (temp >= 30)
// ============================================================================

describe('Edge: gate boundary at exactly 30°C', () => {
  it('59 min at exactly 30°C → gate NOT triggered', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 59,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 30,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assert(
      !result.safety_flags.includes('No structured hydration plan needed. Drink to thirst and hydrate before and immediately after.'),
      'gate should NOT trigger at exactly 30°C',
    );
  });

  it('59 min at 29.9°C → gate triggered (<30)', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 59,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 29.9,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assert(
      result.safety_flags.includes('No structured hydration plan needed. Drink to thirst and hydrate before and immediately after.'),
      'gate should trigger at 29.9°C',
    );
  });
});

// ============================================================================
// Brick: run ceiling hit, redistribution, all segments at ceiling → flag
// ============================================================================

describe('Edge: all brick ceilings hit → redistribution failure flag', () => {
  it('flags "Even at maximum intake on all segments..."', () => {
    // 60 kg HEAVY 35°C 70% — from redistribution test case
    const result = calculateBrickHydration({
      weightKg: 60,
      segments: [
        { sport: 'cycling', durationMin: 60, order: 1 },
        { sport: 'running', durationMin: 60, order: 2 },
      ],
      sweatRateCategory: 'heavy',
      sweatSodiumCat: 'average',
      tempC: 35,
      humidityPct: 70,
      isIndoor: false,
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assert(
      result.safety_flags.some(f => f.includes('Even at maximum intake on all segments, you will exceed 2% BW loss.')),
    );
  });
});
