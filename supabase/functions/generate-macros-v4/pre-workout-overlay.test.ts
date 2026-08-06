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

// ============================================================================
// Hydration v6 / carbs v2 / sodium v3 on the response payload.
//
// The v1 assertions that lived here (fluid = BW x 6, a [BW x 5, BW x 7] band,
// a flat 250 ml "tier 2", 450/150 mg of sodium and `pre_run_hydration_tier`)
// were DELETED, not adapted: every number changed and the integer tier field
// no longer exists. `pre_run_hydration_regime` + `pre_run_fluid_target_basis`
// are what a consumer reads now.
//
// 70 kg reference athlete, 10 mi @ 9 min/mi = 90 min (above the gate).
// ============================================================================

describe('Pre-workout overlay — cited regime (t >= 120)', () => {
  it('70 kg, 3 h before, 22 C -> 525 ml [350, 840], regime=cited', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({ hours_before: 3, temp_c: 22 }),
      EMPTY_TEMPLATES,
    );
    // 7.5 ml/kg (Thomas 2016 midpoint), NOT v1's 6 ml/kg.
    assertEquals(result.pre_run_water_ml, 525);
    assertEquals(result.pre_run_water_low_ml, 350);   // 5 * BW, cited floor
    assertEquals(result.pre_run_water_high_ml, 840);  // min(12.5, 12) * BW
    assertEquals(result.pre_run_hydration_regime, 'cited');
    assertEquals(result.pre_run_fluid_target_basis, 'evidenced_band');
    assertEquals(result.pre_run_hydration_gate_triggered, false);
    // `unknown` normalises to `pale` above T_REF -- and only there.
    assertEquals(result.pre_run_hydration_check_used, 'pale');
    assertEquals(
      result.pre_run_fluid_tiers.map((t: { tier: string }) => t.tier),
      ['meal', 'snack', 'top_off'],
    );

    // Sodium v3: no pre-workout target. STRICT null -- a 0 here would mean
    // "consume no sodium", which is a different claim and a real regression.
    assertEquals(result.pre_run_sodium_mg, null);
    assertEquals(result.pre_run_sodium_low_mg, null);
    assertEquals(result.pre_run_sodium_high_mg, null);

    // Carbs v2: t = 180 -> 3 g/kg = 210 g, plan band Thomas [1*BW, 4*BW].
    assertEquals(result.pre_run_carbs_g, 210);
    assertEquals(result.pre_run_carbs_low_g, 70);
    assertEquals(result.pre_run_carbs_high_g, 280);
    assertEquals(result.pre_run_carb_target_basis, 'evidenced_band');
    assertEquals(
      result.pre_run_carb_tiers.map((t: { tier: string }) => t.tier),
      ['meal', 'snack', 'top_off'],
    );
  });

  // REVERSED, deliberately (Lee, 2026-08-05). This assertion previously read
  // "the retired `pre_run_hydration_tier` is absent from the payload" and
  // required the integer never to reappear. Dropping it turned out to break
  // every shipped client: App Store builds up to 1.22.x read the integer, and
  // with the key gone they silently fall back to their offline path and lose
  // the server's pre-workout hydration entirely. That is the PW-013 hazard the
  // spec names, and it bites on any deploy that lands before the matching app
  // build reaches users.
  //
  // So the integer is emitted ALONGSIDE the regime. The contract is now
  // "present and faithful to the retired rule", not "absent".
  it('still emits the retired `pre_run_hydration_tier` for pre-1.23 clients', async () => {
    const result = (await calculateMacrosV4(
      baseRunningInput({ hours_before: 3, temp_c: 22 }),
      EMPTY_TEMPLATES,
    )) as Record<string, unknown>;

    assert(
      'pre_run_hydration_tier' in result,
      'PW-013: clients up to 1.22.x read this key. Removing it does not crash '
        + 'them — it empties their pre-workout hydration, which is worse '
        + 'because nothing reports it. Remove only once no supported client '
        + 'reads it.',
    );
    // t = 180 min >= 120, 90 min workout so the gate is not triggered -> 1.
    assertEquals(result.pre_run_hydration_tier, 1);
    // And the replacement is emitted too — this is dual-emit, not a revert.
    assertEquals(result.pre_run_hydration_regime, 'cited');
  });

  it('the legacy tier tracks the retired rule, not the new regime', async () => {
    // t = 45 min: new regime is `extrapolated`, retired tier is 2.
    const mid = (await calculateMacrosV4(
      baseRunningInput({ hours_before: 0.75, temp_c: 22 }),
      EMPTY_TEMPLATES,
    )) as Record<string, unknown>;
    assertEquals(mid.pre_run_hydration_tier, 2);

    // The case a regime->tier map gets wrong: a gated plan emitted tier 1
    // under the retired rule regardless of lead time. Duration comes from
    // distance x pace, so 3 mi @ 9 min/mi = 27 min puts it under the 60 min
    // gate; at t = 0 the ungated rule would say 3.
    const gated = (await calculateMacrosV4(
      baseRunningInput({ hours_before: 0, temp_c: 22, run_distance: 3 }),
      EMPTY_TEMPLATES,
    )) as Record<string, unknown>;
    assertEquals(gated.pre_run_hydration_tier, 1);
    assertEquals(gated.pre_run_hydration_gate_triggered, true);
  });
});

describe('Pre-workout overlay — extrapolated regime (30 <= t < 120)', () => {
  it('70 kg, 45 min before -> taper 353 ml, low 0, regime=extrapolated', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({
        hours_before: 45 / 60,
        temp_c: 22,
        run_distance: 10,
      }),
      EMPTY_TEMPLATES,
    );
    // f(45) = 250 + (525 - 250) * 45/120 = 353.125 -> 353 at the response
    // boundary. There is no flat 250 ml tier any more.
    assertEquals(result.pre_run_water_ml, 353);
    // Below two hours there is NO minimum: 0, and 0 is not null here.
    assertEquals(result.pre_run_water_low_ml, 0);
    assertEquals(result.pre_run_water_high_ml, 700); // min(10*BW, clearance)
    assertEquals(result.pre_run_hydration_regime, 'extrapolated');
    assertEquals(result.pre_run_fluid_target_basis, 'design_choice');
    // Below T_REF the echo is RAW -- never normalised to pale.
    assertEquals(result.pre_run_hydration_check_used, 'unknown');
    assertEquals(
      result.pre_run_fluid_tiers.map((t: { tier: string }) => t.tier),
      ['snack', 'top_off'],
    );
    assertEquals(result.pre_run_sodium_mg, null);
  });
});

describe('Pre-workout overlay — clearance_bound regime (t < 30)', () => {
  it('5 min before -> top-off only, high clamped by gastric clearance', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({
        hours_before: 5 / 60,
        temp_c: 22,
        run_distance: 10, // 90 min, so the gate does not fire
      }),
      EMPTY_TEMPLATES,
    );
    // f(5) = 261.46 -> 261. Carbs are what go to zero this close in, not fluid:
    // "you can drink at the gun, not eat".
    assertEquals(result.pre_run_water_ml, 261);
    assertEquals(result.pre_run_water_low_ml, 0);
    // 400 * e^(3.2/60 * 5) = 522.24 < 10*BW=700 -> the clearance ceiling binds.
    assertEquals(result.pre_run_water_high_ml, 522);
    assertEquals(result.pre_run_hydration_regime, 'clearance_bound');
    assertEquals(result.pre_run_fluid_target_basis, 'design_choice');
    assertEquals(
      result.pre_run_fluid_tiers.map((t: { tier: string }) => t.tier),
      ['top_off'],
    );
    assertEquals(result.pre_run_sodium_mg, null);
    assertEquals(result.pre_run_hydration_gate_triggered, false);
  });
});

describe('Pre-workout overlay — the gate', () => {
  it('45 min workout at 22 C -> gated: fluid null (not 0), no tiers', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({
        hours_before: 3, temp_c: 22,
        run_distance: 5, run_pace: 9,  // 5 x 9 = 45 min
      }),
      EMPTY_TEMPLATES,
    );
    assertEquals(result.pre_run_water_ml, null, 'gated fluid is null, not 0');
    assertEquals(result.pre_run_water_low_ml, null);
    assertEquals(result.pre_run_water_high_ml, null);
    assertEquals(result.pre_run_sodium_mg, null);
    assertEquals(result.pre_run_hydration_gate_triggered, true);
    assertEquals(result.pre_run_hydration_regime, 'gated');
    assertEquals(result.pre_run_fluid_target_basis, 'none');
    assertEquals(result.pre_run_hydration_check_used, null);
    assertEquals(result.pre_run_fluid_tiers.length, 0);
    assert(
      (result.pre_run_hydration_message ?? '').includes('No structured pre-hydration'),
      'gate message present',
    );
    // Carbs have NO gate -- deliberately asymmetric with hydration.
    assertEquals(result.pre_run_carbs_g, 210);
    assert(
      result.pre_run_carb_tiers.length > 0,
      'a gated hydration plan must not empty the carb tiers',
    );
  });

  it('45 min workout at 31 C -> gate bypassed, cited regime applies', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({
        hours_before: 3, temp_c: 31,
        run_distance: 5, run_pace: 9,
      }),
      EMPTY_TEMPLATES,
    );
    assertEquals(result.pre_run_water_ml, 525);
    assertEquals(result.pre_run_hydration_gate_triggered, false);
    assertEquals(result.pre_run_hydration_regime, 'cited');
  });
});

describe('Pre-workout overlay — fasted', () => {
  it('fasted zeroes carbs but still hydrates (the gate is duration/temp only)', async () => {
    const result = await calculateMacrosV4(
      baseRunningInput({ hours_before: 3, is_fasted: true, run_distance: 10 }),
      EMPTY_TEMPLATES,
    );
    assertEquals(result.pre_run_water_ml, 525);
    assertEquals(result.pre_run_hydration_regime, 'cited');
    assertEquals(result.pre_run_sodium_mg, null);
    assertEquals(result.pre_run_meal_type, 'fasted');
    assertEquals(result.pre_run_carbs_g, 0);
    assertEquals(result.pre_run_protein_g, 0);
    // The two zeros are DIFFERENT: fasted means "no recommendation is being
    // made", so the tiers are EMPTY and the basis is `none` -- distinct from a
    // t = 0 plan, which carries a top_off tier holding 0 g.
    assertEquals(result.pre_run_carb_tiers.length, 0);
    assertEquals(result.pre_run_carb_target_basis, 'none');
  });
});

describe('Pre-workout overlay — brick path (Olympic tri)', () => {
  it('brick 140 min, 4 h before, 68 kg → cited-regime overlay', () => {
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

    // Cited regime for 68 kg: 7.5 * 68 = 510, band [5 * 68, 12 * 68].
    assertEquals(result.phases.before.water_ml, 510);
    assertEquals(result.phases.before.water_low_ml, 340);
    assertEquals(result.phases.before.water_high_ml, 816);
    // Sodium v3 -- strict null, on the brick path too.
    assertEquals(result.phases.before.sodium_mg, null);
    assertEquals(result.phases.before.sodium_low_mg, null);
    assertEquals(result.phases.before.sodium_high_mg, null);
    assertEquals(
      result.phases.before.water_tiers.map((t: { tier: string }) => t.tier),
      ['meal', 'snack', 'top_off'],
    );
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
