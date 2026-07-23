/**
 * Pre-Workout Hydration Tests (new algorithm)
 *
 * Ported verbatim from /docs/sodium_hydration/hydration_sodium_calc_tests.md PART 2
 *
 * Run with:
 *   deno test supabase/functions/generate-macros-v4/pre-workout-new.test.ts
 */

import {
  assertEquals,
  assertAlmostEquals,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { calculatePreWorkoutHydration } from './pre-workout.ts';

// ============================================================================
// Pre-Workout Gate Tests
// ============================================================================

describe('Pre-Workout Gate', () => {
  it('45 min at 22°C → gate triggered (< 60 AND < 30)', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 45,
      timeBeforeWorkoutMin: 180,
      tempC: 22,
    });
    assert(result.gate_triggered, 'gate should trigger');
    assertEquals(result.fluid_ml, 0, 'no fluid when gated');
    assert(result.message?.includes('No structured pre-hydration needed'), 'message includes gate copy');
  });

  it('45 min at 31°C → gate NOT triggered (temp >= 30)', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 45,
      timeBeforeWorkoutMin: 180,
      tempC: 31,
    });
    assert(!result.gate_triggered, 'gate should not trigger');
    assert(result.fluid_ml > 0, 'fluid should be non-zero');
  });

  it('60 min at 22°C → gate NOT triggered (not < 60)', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 60,
      timeBeforeWorkoutMin: 180,
      tempC: 22,
    });
    assert(!result.gate_triggered);
  });

  it('59 min at 29°C → gate triggered', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 59,
      timeBeforeWorkoutMin: 180,
      tempC: 29,
    });
    assert(result.gate_triggered);
  });

  it('90 min at 15°C → gate NOT triggered (not < 60)', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 180,
      tempC: 15,
    });
    assert(!result.gate_triggered);
  });
});

// ============================================================================
// Pre-Workout Tier Selection
// ============================================================================

describe('Pre-Workout Tier Selection', () => {
  it('240 min before → Tier 1', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 240,
      tempC: 22,
    });
    assertEquals(result.tier, 1);
  });

  it('120 min before → Tier 1 (exact boundary)', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 120,
      tempC: 22,
    });
    assertEquals(result.tier, 1);
  });

  it('119 min before → Tier 2 (just under 120)', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 119,
      tempC: 22,
    });
    assertEquals(result.tier, 2);
  });

  it('90 min before → Tier 2', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 90,
      tempC: 22,
    });
    assertEquals(result.tier, 2);
  });

  it('45 min before → Tier 2', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 45,
      tempC: 22,
    });
    assertEquals(result.tier, 2);
  });

  it('10 min before → Tier 2 (exact boundary)', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 10,
      tempC: 22,
    });
    assertEquals(result.tier, 2);
  });

  it('9 min before → Tier 3', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 9,
      tempC: 22,
    });
    assertEquals(result.tier, 3);
  });

  it('5 min before → Tier 3', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 5,
      tempC: 22,
    });
    assertEquals(result.tier, 3);
  });

  it('0 min before → Tier 3 (edge: zero time)', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 0,
      tempC: 22,
    });
    assertEquals(result.tier, 3);
  });
});

// ============================================================================
// Pre-Test 1: 45-min speedwork, nice day (gate fires)
// ============================================================================

describe('Pre-Test 1: gate fires', () => {
  it('returns fluid=0 and gate message', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 45,
      timeBeforeWorkoutMin: 180,
      tempC: 22,
    });
    assertEquals(result.fluid_ml, 0);
    assert(result.message?.includes('No structured pre-hydration needed'));
  });
});

// ============================================================================
// Pre-Test 2: 90-min long run, 3 hours available (Tier 1)
// ============================================================================

describe('Pre-Test 2: Tier 1 (180 min before, 65 kg)', () => {
  it('returns fluid=390, range=[325,455], sodium=450, range=[300,600]', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 65,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 180,
      tempC: 14,
    });
    assertEquals(result.tier, 1);
    assertEquals(result.fluid_ml, 65 * 6); // 390
    assertEquals(result.fluid_low_ml, 65 * 5); // 325
    assertEquals(result.fluid_high_ml, 65 * 7); // 455
    assertEquals(result.sodium_mg, 450);
    assertEquals(result.sodium_low_mg, 300);
    assertEquals(result.sodium_high_mg, 600);
  });
});

// ============================================================================
// Pre-Test 3: 3-hour bike, 90 min available (Tier 2)
// ============================================================================

describe('Pre-Test 3: Tier 2 (90 min before, 80 kg)', () => {
  it('returns fluid=250, range=[200,300], sodium=150, range=[100,200]', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 80,
      workoutDurationMin: 180,
      timeBeforeWorkoutMin: 90,
      tempC: 31,
    });
    assertEquals(result.tier, 2);
    assertEquals(result.fluid_ml, 250);
    assertEquals(result.fluid_low_ml, 200);
    assertEquals(result.fluid_high_ml, 300);
    assertEquals(result.sodium_mg, 150);
    assertEquals(result.sodium_low_mg, 100);
    assertEquals(result.sodium_high_mg, 200);
    assert(result.message?.includes('consider hydrating well the evening before'));
  });
});

// ============================================================================
// Pre-Test 4: Olympic triathlon, 4 hours available (Tier 1)
// ============================================================================

describe('Pre-Test 4: Tier 1 (240 min before, 68 kg)', () => {
  it('returns fluid=408, range=[340,476], sodium=450', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 68,
      workoutDurationMin: 140,
      timeBeforeWorkoutMin: 240,
      tempC: 26,
    });
    assertEquals(result.tier, 1);
    assertEquals(result.fluid_ml, 68 * 6); // 408
    assertEquals(result.fluid_low_ml, 68 * 5); // 340
    assertEquals(result.fluid_high_ml, 68 * 7); // 476
    assertEquals(result.sodium_mg, 450);
  });
});

// ============================================================================
// Pre-Test 5: Early morning run, 45 min available (Tier 2)
// ============================================================================

describe('Pre-Test 5: Tier 2 (45 min before, 70 kg)', () => {
  it('returns fixed 250/150 targets', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 45,
      tempC: 22,
    });
    assertEquals(result.tier, 2);
    assertEquals(result.fluid_ml, 250);
    assertEquals(result.sodium_mg, 150);
    assert(result.message?.includes('consider hydrating well the evening before'));
  });
});

// ============================================================================
// Pre-Test 6: 5 min before (Tier 3)
// ============================================================================

describe('Pre-Test 6: Tier 3 (5 min before, 75 kg)', () => {
  it('returns fluid=0, sodium=0 with too-late message', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 75,
      workoutDurationMin: 120,
      timeBeforeWorkoutMin: 5,
      tempC: 25,
    });
    assertEquals(result.tier, 3);
    assertEquals(result.fluid_ml, 0);
    assertEquals(result.sodium_mg, 0);
    assert(result.message?.includes('Too late for structured pre-hydration'));
  });
});

// ============================================================================
// Pre-Test 7: Short hot workout — gate bypassed (Tier 1)
// ============================================================================

describe('Pre-Test 7: gate bypassed by temp >= 30, Tier 1 (150 min before, 72 kg)', () => {
  it('returns Tier 1 values for 72 kg', () => {
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 72,
      workoutDurationMin: 45,
      timeBeforeWorkoutMin: 150,
      tempC: 33,
    });
    assert(!result.gate_triggered, 'gate bypassed');
    assertEquals(result.tier, 1);
    assertEquals(result.fluid_ml, 72 * 6); // 432
    assertEquals(result.fluid_low_ml, 72 * 5); // 360
    assertEquals(result.fluid_high_ml, 72 * 7); // 504
    assertEquals(result.sodium_mg, 450);
  });
});

// ============================================================================
// Tier 1+2 Combined Top-Up (Pre-Test 4 informational)
// ============================================================================

describe('Tier 1 + Tier 2 combined top-up (informational)', () => {
  it('total_fluid = 408 + 250 = 658, total_sodium = 450 + 150 = 600', () => {
    const tier1 = calculatePreWorkoutHydration({
      bodyWeightKg: 68,
      workoutDurationMin: 140,
      timeBeforeWorkoutMin: 240,
      tempC: 26,
    });
    const tier2 = calculatePreWorkoutHydration({
      bodyWeightKg: 68,
      workoutDurationMin: 140,
      timeBeforeWorkoutMin: 60, // Tier 2
      tempC: 26,
    });
    assertEquals(tier1.fluid_ml + tier2.fluid_ml, 408 + 250);
    assertEquals(tier1.sodium_mg + tier2.sodium_mg, 450 + 150);
  });
});

// ============================================================================
// Pre-workout edge cases (G8 — 2026-04-24)
// ============================================================================

describe('Pre-workout edge: timeBeforeWorkoutMin < 0', () => {
  it('negative time is treated as Tier 3 (too late)', () => {
    // Spec §Pre-Workout Edge Cases calls for REJECT. Current impl
    // silently falls through both tier gates (>= 120 is false, >= 10 is
    // false) and returns Tier 3 with 0 ml / 0 mg. Locked in here so we
    // notice if the behavior flips.
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: -15,
      tempC: 22,
    });
    assertEquals(result.tier, 3);
    assertEquals(result.fluid_ml, 0);
    assertEquals(result.sodium_mg, 0);
    assertEquals(
      result.message?.includes('Too late for structured pre-hydration'),
      true,
    );
  });
});

describe('Pre-workout edge: bodyWeightKg = 0', () => {
  it('Tier 1 with BW=0 → fluid=0 (body weight × 6 = 0)', () => {
    // Current impl: Tier 1 formula `BW × 6` produces 0 when BW=0.
    // Sodium stays at the fixed 450 mg (not BW-scaled per spec).
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 0,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 180,
      tempC: 22,
    });
    assertEquals(result.tier, 1);
    assertEquals(result.fluid_ml, 0, 'BW=0 → 0 fluid');
    assertEquals(result.fluid_low_ml, 0);
    assertEquals(result.fluid_high_ml, 0);
    assertEquals(result.sodium_mg, 450, 'sodium not BW-scaled');
  });

  it('Tier 2 with BW=0 → fluid=250 (fixed, not BW-scaled)', () => {
    // Tier 2 uses a fixed 250 ml / 150 mg regardless of body weight.
    final: {
      const result = calculatePreWorkoutHydration({
        bodyWeightKg: 0,
        workoutDurationMin: 90,
        timeBeforeWorkoutMin: 60,
        tempC: 22,
      });
      assertEquals(result.tier, 2);
      assertEquals(result.fluid_ml, 250);
      assertEquals(result.sodium_mg, 150);
    }
  });
});

describe('Pre-workout gate edge: temp=30 exact boundary', () => {
  it('45 min at exactly 30°C → gate bypassed (temp >= 30)', () => {
    // Spec: gate is duration < 60 AND temp < 30 (strict inequalities).
    // At temp=30 the condition is false → full protocol runs.
    const result = calculatePreWorkoutHydration({
      bodyWeightKg: 70,
      workoutDurationMin: 45,
      timeBeforeWorkoutMin: 180,
      tempC: 30,
    });
    assertEquals(result.gate_triggered, false);
    assertEquals(result.tier, 1);
    assertEquals(result.fluid_ml, 70 * 6);
  });
});
