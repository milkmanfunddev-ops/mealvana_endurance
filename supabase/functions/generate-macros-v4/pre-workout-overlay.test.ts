/**
 * Integration tests for pre-workout hydration overlay.
 *
 * These tests exercise calculateMacrosV4 / calculateBrickMacrosV4 directly
 * (bypassing the HTTP handler, which requires Supabase credentials) and
 * assert that the output uses the spec time-tier algorithm rather than the
 * legacy meal-type-scaled formula.
 *
 * Covers the wiring bug fixed in this branch: the spec `calculatePreWorkoutHydration`
 * is now applied as an overlay on top of `calculatePreWorkoutTargets`.
 */

import { assertEquals, assert } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { calculateMacrosV4 } from './single-sport.ts';
import { calculateBrickMacrosV4 } from './brick-workout.ts';
import {
  calculatePreWorkoutHydration,
  calculatePreWorkoutTargets,
  applyPreWorkoutHydrationOverlay,
} from './pre-workout.ts';

// Minimal empty templates — we don't exercise food selection here.
const EMPTY_TEMPLATES = { food: [], drink: [], electrolyte: [] };

function baseRunningInput(overrides: Record<string, unknown> = {}) {
  return {
    weight: 70, weight_unit: 'kg',
    activity_type: 'running',
    hours_before: 3,
    is_fasted: false,
    // Default 10 mi @ 9 min/mi = 90 min (above the gate threshold).
    run_distance: 10, run_distance_unit: 'mi',
    run_pace: 9,
    run_pace_unit: 'min_per_mile',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'average',
    temp_c: 20,
    humidity_pct: 50,
    is_indoor: false,
    ...overrides,
  } as Parameters<typeof calculateMacrosV4>[0];
}

describe('Pre-workout hydration overlay — single-sport Tier 1', () => {
  it('70 kg, 3h before, 22°C → fluid=420 (not legacy 455)', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({ hours_before: 3, temp_c: 22 }),
      EMPTY_TEMPLATES,
    );
    // Spec: weight × 6 = 70 × 6 = 420 ml
    assertEquals(result.pre_run_water_ml, 420);
    assertEquals(result.pre_run_water_low_ml, 350);  // weight × 5
    assertEquals(result.pre_run_water_high_ml, 490); // weight × 7
    assertEquals(result.pre_run_sodium_mg, 450);
    assertEquals(result.pre_run_sodium_low_mg, 300);
    assertEquals(result.pre_run_sodium_high_mg, 600);
    assertEquals(result.pre_run_hydration_tier, 1);
    assertEquals(result.pre_run_hydration_gate_triggered, false);
  });
});

describe('Pre-workout hydration overlay — single-sport Tier 2', () => {
  it('70 kg, 45 min before, 22°C, 90 min workout → fixed 250ml / 150mg', async () => {
    // 45 min run @ 9 min/mile = 5 miles, durationMin=45 → gate would fire at 22°C
    // So use 90 min run so gate doesn't fire
    const result = await calculateMacrosV4(
      baseRunningInput({
        hours_before: 45 / 60,
        temp_c: 22,
        run_distance: 10,
      }),
      EMPTY_TEMPLATES,
    );
    assertEquals(result.pre_run_water_ml, 250);
    assertEquals(result.pre_run_water_low_ml, 200);
    assertEquals(result.pre_run_water_high_ml, 300);
    assertEquals(result.pre_run_sodium_mg, 150);
    assertEquals(result.pre_run_hydration_tier, 2);
  });
});

describe('Pre-workout hydration overlay — gate triggers', () => {
  it('45 min workout at 22°C → gate fires → fluid=0, sodium=0', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({
        hours_before: 3, temp_c: 22,
        run_distance: 5, run_pace: 9,  // 5 × 9 = 45 min
      }),
      EMPTY_TEMPLATES,
    );
    assertEquals(result.pre_run_water_ml, 0);
    assertEquals(result.pre_run_sodium_mg, 0);
    assertEquals(result.pre_run_hydration_gate_triggered, true);
    assert(
      (result.pre_run_hydration_message ?? '').includes('No structured pre-hydration'),
      'gate message present',
    );
  });

  it('45 min workout at 31°C → gate bypassed, Tier 1 applies', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({
        hours_before: 3, temp_c: 31,
        run_distance: 5, run_pace: 9,
      }),
      EMPTY_TEMPLATES,
    );
    assertEquals(result.pre_run_water_ml, 420);
    assertEquals(result.pre_run_hydration_gate_triggered, false);
    assertEquals(result.pre_run_hydration_tier, 1);
  });
});

describe('Pre-workout hydration overlay — Tier 3 too-late', () => {
  it('5 min before, 90 min workout → fluid=0, sodium=0, Tier 3', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({
        hours_before: 5 / 60,
        temp_c: 22,
        run_distance: 10,  // 10 × 9 = 90 min
      }),
      EMPTY_TEMPLATES,
    );
    assertEquals(result.pre_run_water_ml, 0);
    assertEquals(result.pre_run_sodium_mg, 0);
    assertEquals(result.pre_run_hydration_tier, 3);
    assertEquals(result.pre_run_hydration_gate_triggered, false);
  });
});

describe('Pre-workout hydration overlay — fasted skips overlay', () => {
  it('fasted → overlay not applied, legacy zeros preserved', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({ hours_before: 3, is_fasted: true, run_distance: 10 }),
      EMPTY_TEMPLATES,
    );
    // Fasted legacy path returns 0 for all macros including water/sodium.
    assertEquals(result.pre_run_water_ml, 0);
    assertEquals(result.pre_run_sodium_mg, 0);
    assertEquals(result.pre_run_meal_type, 'fasted');
  });
});

describe('Pre-workout hydration overlay — brick path (Olympic tri)', () => {
  it('brick 140 min, 4h before, 68 kg → Tier 1 overlay', () => {
    const input = {
      weight: 68, weight_unit: 'kg',
      activity_type: 'brick',
      hours_before: 4,
      is_fasted: false,
      sweat_rate_category: 'medium',
      sweat_sodium: 'average',
      gut_training: 'moderate',
      temp_c: 26, humidity_pct: 55, is_indoor: false,
      brick_segments: [
        { sport: 'swimming', order: 1, duration_minutes: 25, intensity: 'moderate', distance_meters: 1500 },
        { sport: 'cycling', order: 2, duration_minutes: 65, intensity: 'moderate', speed_mph: 25, distance_miles: 27 },
        { sport: 'running', order: 3, duration_minutes: 50, intensity: 'moderate', pace_minutes_per_mile: 9, distance_miles: 5.5 },
      ],
    } as Parameters<typeof calculateBrickMacrosV4>[0];

    // Manually exercise the same overlay that index.ts applies.
    const totalDurationMin = (input.brick_segments ?? [])
      .reduce((s, seg) => s + seg.duration_minutes, 0);
    const legacy = calculatePreWorkoutTargets(
      68, input.hours_before, false, input.sweat_sodium, 'warm',
    );
    const hydration = calculatePreWorkoutHydration({
      bodyWeightKg: 68,
      workoutDurationMin: totalDurationMin,
      timeBeforeWorkoutMin: input.hours_before * 60,
      tempC: input.temp_c ?? null,
    });
    const preTargets = applyPreWorkoutHydrationOverlay(legacy, hydration);

    const result = calculateBrickMacrosV4(input, preTargets);

    // Tier 1 values for 68 kg: fluid=408, sodium=450
    assertEquals(result.phases.before.water_ml, 408);
    assertEquals(result.phases.before.water_low_ml, 340);
    assertEquals(result.phases.before.water_high_ml, 476);
    assertEquals(result.phases.before.sodium_mg, 450);
  });
});

describe('Pre-workout hydration overlay — breakdown fields', () => {
  it('exposes replacement_band and multipliers for transparency UI', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({ hours_before: 3, temp_c: 26, humidity_pct: 55, run_distance: 15 }),
      EMPTY_TEMPLATES,
    );
    // 15 miles × 9 min/mile = 135 min → 90-150 band
    assertEquals(result.replacement_band, '90–150 min');
    assertEquals(result.replacement_pct, 0.60);
    // temp 26 → 1 + (26-22)*0.04 = 1.16
    assertEquals(result.temp_mult, 1.16);
    // humidity 55 → 1 + (55-50)*0.002 = 1.01
    assertEquals(result.humidity_mult, 1.01);
    assertEquals(result.indoor_mult, 1);
    assertEquals(result.base_sweat_rate_lph, 1.28);
  });
});
