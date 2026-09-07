/**
 * Multi-Segment (Brick) Workout Hydration Tests
 *
 * Ported verbatim from /docs/features/sodium_hydration/hydration_sodium_calc_tests.md
 * §Multi-Segment Integration Tests and §Redistribution Test
 *
 * Run with:
 *   deno test supabase/functions/generate-macros-v4/brick-workout-new.test.ts
 */

import {
  assertEquals,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { calculateBrickHydration } from './brick-workout.ts';
import { calculateBrickMacrosV4 } from './brick-workout.ts';
import { calculateTransitionCarbDose } from './brick-workout.ts';
import {
  applyPreWorkoutHydrationOverlay,
  calculatePreWorkoutHydration,
  calculatePreWorkoutTargets,
} from './pre-workout.ts';

const ML_TOL = 0.05; // 5%

function assertMlClose(actual: number, expected: number, msg?: string) {
  const tol = Math.max(5, expected * ML_TOL);
  const diff = Math.abs(actual - expected);
  assert(diff <= tol, `${msg ?? ''} Expected ${expected} ±${tol.toFixed(1)}, got ${actual}`);
}

// ============================================================================
// Example 5: Olympic Triathlon, warm day
// ============================================================================

describe('Example 5: Olympic Triathlon (known rate 1300, 26°C, 55%)', () => {
  it('returns correct per-segment fluid rates and transitions', () => {
    // Athlete: 68 kg, known sweat rate 1300 ml/hr
    // Conditions: 26°C, 55% humidity, outdoor
    // Segments: Swim 25 min, Bike 65 min, Run 50 min
    // Expected:
    //   Swim: 0 ml/hr
    //   T1:   300 ml
    //   Bike: 679 ml/hr
    //   T2:   300 ml
    //   Run:  679 ml/hr
    const result = calculateBrickHydration({
      weightKg: 68,
      segments: [
        { sport: 'swimming', durationMin: 25, order: 1 },
        { sport: 'cycling',  durationMin: 65, order: 2 },
        { sport: 'running',  durationMin: 50, order: 3 },
      ],
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 26,
      humidityPct: 55,
      isIndoor: false,
      knownSweatRateMlPerHour: 1300,
      knownSodiumConcMgPerL: null,
    });

    // Swim = 0
    const swimSeg = result.segments.find(s => s.sport === 'swimming')!;
    assertEquals(swimSeg.hydration_rate_mlph, 0, 'swim rate = 0');

    // T1 = 300 ml
    const t1 = result.transitions.find(t => t.transition_name === 'T1')!;
    assertEquals(t1.water_ml, 300, 'T1 = 300 ml');

    // Bike ~679
    const bikeSeg = result.segments.find(s => s.sport === 'cycling')!;
    assertMlClose(bikeSeg.hydration_rate_mlph, 679, 'bike rate');

    // T2 = 300 ml
    const t2 = result.transitions.find(t => t.transition_name === 'T2')!;
    assertEquals(t2.water_ml, 300, 'T2 = 300 ml');

    // Run ~679
    const runSeg = result.segments.find(s => s.sport === 'running')!;
    assertMlClose(runSeg.hydration_rate_mlph, 679, 'run rate');

    // Total intake check: 300 + 65/60*679 + 300 + 50/60*679 ≈ 1897 ml
    const totalIntake = t1.water_ml +
      Math.round(bikeSeg.hydration_rate_mlph * 65 / 60) +
      t2.water_ml +
      Math.round(runSeg.hydration_rate_mlph * 50 / 60);
    assertMlClose(totalIntake, 1897, 'total intake');
  });
});

// ============================================================================
// Example 6: Brick workout (bike → run), warm day
// ============================================================================

describe('Example 6: Brick (bike 90 min → run 45 min), 27°C', () => {
  it('returns correct per-segment fluid rates', () => {
    // Athlete: 72 kg, MEDIUM sweater, 27°C, 50%, outdoor
    // Segments: Bike 90 min, Run 45 min
    // effective = 1.28 * 1.20 = 1.536 L/hr
    // total = 135 min → 0.60 replacement
    // losses: bike=2304, run=1152, total=3456
    // required=2074; T2=300; remaining=1774
    // drinkable = (90+45)/60 = 2.25 hr
    // recommended = 1774/2.25 = 789 ml/hr
    // Expected: Bike=789, T2=300, Run=789
    const result = calculateBrickHydration({
      weightKg: 72,
      segments: [
        { sport: 'cycling', durationMin: 90, order: 1 },
        { sport: 'running', durationMin: 45, order: 2 },
      ],
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 27,
      humidityPct: 50,
      isIndoor: false,
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });

    const bikeSeg = result.segments.find(s => s.sport === 'cycling')!;
    assertMlClose(bikeSeg.hydration_rate_mlph, 789, 'bike rate');

    // Single gap = T1 (positional, brick.md R8)
    const t2 = result.transitions.find(t => t.transition_name === 'T1')!;
    assertEquals(t2.water_ml, 300, 'T1 = 300 ml');

    const runSeg = result.segments.find(s => s.sport === 'running')!;
    assertMlClose(runSeg.hydration_rate_mlph, 789, 'run rate');

    // No redistribution expected
    assert(!result.safety_flags.some(f => f.includes('maximum intake on all segments')),
      'no redistribution flag');
  });
});

// ============================================================================
// Redistribution Test: run ceiling forces shift to bike
// ============================================================================

describe('Redistribution: heavy sweater, run ceiling hit, shift to bike', () => {
  it('returns Bike=1200, T2=300, Run=800 with flags', () => {
    // Athlete: 60 kg, HEAVY sweater, 35°C, 70%, outdoor
    // Segments: Bike 60 min, Run 60 min
    // effective = 1.66 * 1.52 * 1.04 = 2.625 L/hr → within clamp
    // total = 120 min → 0.60 replacement
    // losses: bike=2625, run=2625, total=5250
    // required=3150; T2=300; remaining=2850
    // drinkable = 2.0 hr; recommended=1425 ml/hr
    // floor=(5250-1200)=4050; remaining=3750; floor=1875
    // Floor>ceiling in run (1875>800), redistribution needed
    // Bike receives shortfall but also hits 1200 ceiling
    // → still deficit → flag
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

    const bikeSeg = result.segments.find(s => s.sport === 'cycling')!;
    assertEquals(bikeSeg.hydration_rate_mlph, 1200, 'bike capped at 1200');

    // Single gap = T1 (positional, brick.md R8)
    const t2 = result.transitions.find(t => t.transition_name === 'T1')!;
    assertEquals(t2.water_ml, 300, 'T1 = 300 ml');

    const runSeg = result.segments.find(s => s.sport === 'running')!;
    assertEquals(runSeg.hydration_rate_mlph, 800, 'run capped at 800');

    assert(
      result.safety_flags.some(f => f.includes('Even at maximum intake on all segments, you will exceed 2% BW loss.')),
      'redistribution failure flag',
    );
    assert(
      result.safety_flags.some(f => f.includes('Significant dehydration expected')),
      'significant dehydration flag',
    );
  });
});

// ============================================================================
// Transition sodium — spec: sodium_mg = (300/1000) × sodium_conc (no 0.3 factor)
// ============================================================================

describe('Transition sodium matches spec (no 0.3 factor)', () => {
  it('AVERAGE sodium (825 mg/L) → each T ≈ 248 mg', () => {
    const result = calculateBrickHydration({
      weightKg: 68,
      segments: [
        { sport: 'swimming', durationMin: 25, order: 1 },
        { sport: 'cycling',  durationMin: 65, order: 2 },
        { sport: 'running',  durationMin: 50, order: 3 },
      ],
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    const expected = Math.round((300 / 1000) * 825); // 248
    const t1 = result.transitions.find(t => t.transition_name === 'T1')!;
    const t2 = result.transitions.find(t => t.transition_name === 'T2')!;
    assertEquals(t1.sodium_mg, expected);
    assertEquals(t2.sodium_mg, expected);
  });

  it('HIGH sodium (1000 mg/L) → each T = 300 mg', () => {
    const result = calculateBrickHydration({
      weightKg: 72,
      segments: [
        { sport: 'cycling', durationMin: 90, order: 1 },
        { sport: 'running', durationMin: 45, order: 2 },
      ],
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'high',
      tempC: 22, humidityPct: 50, isIndoor: false,
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    const t2 = result.transitions.find(t => t.transition_name === 'T1')!;
    assertEquals(t2.sodium_mg, 300);
  });

  it('known sodium concentration overrides category in transitions', () => {
    const result = calculateBrickHydration({
      weightKg: 70,
      segments: [
        { sport: 'cycling', durationMin: 60, order: 1 },
        { sport: 'running', durationMin: 30, order: 2 },
      ],
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'low',
      tempC: 22, humidityPct: 50, isIndoor: false,
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: 900,
    });
    const t2 = result.transitions.find(t => t.transition_name === 'T1')!;
    // (300/1000) × 900 = 270
    assertEquals(t2.sodium_mg, 270);
  });
});

// ============================================================================
// Transition detection: POSITIONAL T{i+1} — brick.md R8 (fixes D-008); the
// sport pair is a display label only (sport_pair field).
// ============================================================================

describe('Transition naming (positional, brick.md R8)', () => {
  it('Olympic tri: gap after leg 1 is T1, after leg 2 is T2', () => {
    const result = calculateBrickHydration({
      weightKg: 70,
      segments: [
        { sport: 'swimming', durationMin: 20, order: 1 },
        { sport: 'cycling',  durationMin: 60, order: 2 },
        { sport: 'running',  durationMin: 40, order: 3 },
      ],
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });

    const t1 = result.transitions.find(t => t.transition_name === 'T1');
    const t2 = result.transitions.find(t => t.transition_name === 'T2');
    assert(t1 !== undefined, 'T1 exists');
    assert(t2 !== undefined, 'T2 exists');
    assertEquals(t1!.after_sport, 'swimming', 'T1 after swim');
    assertEquals(t2!.after_sport, 'cycling', 'T2 after bike');
    assertEquals(t1!.sport_pair, 'swimming→cycling', 'T1 label');
    assertEquals(t2!.sport_pair, 'cycling→running', 'T2 label');
    assertEquals(t1!.water_ml, 300, 'T1 = 300 ml fixed');
    assertEquals(t2!.water_ml, 300, 'T2 = 300 ml fixed');
  });

  // brick.md R8 ruled AGAINST the old sport-pair naming: a plain bike→run
  // brick used to emit T2 with no T1 (D-008 — the consumer looks up T1 and
  // fell to zero-defaults). Positionally the single gap IS T1.
  it('bike→run only brick has T1 (positional; D-008 fixed)', () => {
    const result = calculateBrickHydration({
      weightKg: 70,
      segments: [
        { sport: 'cycling', durationMin: 60, order: 1 },
        { sport: 'running', durationMin: 40, order: 2 },
      ],
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });

    const t1 = result.transitions.find(t => t.transition_name === 'T1');
    const t2 = result.transitions.find(t => t.transition_name === 'T2');
    assert(t1 !== undefined, 'T1 exists for the single bike→run gap');
    assertEquals(t1!.sport_pair, 'cycling→running', 'pair is a label only');
    assert(t2 === undefined, 'no T2 on a 2-leg brick');
    assertEquals(t1!.water_ml, 300, 'T1 = 300 ml');
  });

  it('repeat-leg brick (bike→run→bike) gets T1 and T2, no collision', () => {
    const result = calculateBrickHydration({
      weightKg: 70,
      segments: [
        { sport: 'cycling', durationMin: 40, order: 1 },
        { sport: 'running', durationMin: 30, order: 2 },
        { sport: 'cycling', durationMin: 40, order: 3 },
      ],
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });

    assertEquals(
      result.transitions.map(t => t.transition_name), ['T1', 'T2'],
      'positional names never collide on repeat legs',
    );
    assertEquals(result.transitions[0].sport_pair, 'cycling→running');
    assertEquals(result.transitions[1].sport_pair, 'running→cycling');
  });
});

// ============================================================================
// Integration tests: calculateBrickMacrosV4 production output
// Verifies the production function uses calculateBrickHydration (not old per-
// segment flat replacement) and that both segments share the same replacement %.
// ============================================================================

/**
 * Pre-workout stub for the brick integration tests.
 *
 * `calculateBrickMacrosV4` now requires `PreWorkoutOverlaidTargets`, not the
 * bare `PreWorkoutTargets` map — the overlay carries the v6 fluid tiers, the
 * regime/basis strings and the solver's numeric view, and fluid + sodium are
 * nullable on it. Rather than hand-write that widened shape (and drift from
 * it), build it the way production does: legacy targets, then the real
 * overlay over a real hydration result.
 *
 * These tests assert DURING-phase behaviour; the pre-workout numbers here are
 * only a well-formed input. Pre-workout output is asserted in
 * pre-workout-overlay.test.ts and pinned in pre-workout-vectors.test.ts.
 */
function makePreTargets() {
  const legacy = calculatePreWorkoutTargets(
    /* weightKg */ 72,
    /* hoursBefore */ 3,
    /* isFasted */ false,
    /* sweatSodiumCat */ 'medium',
    /* envLabel */ 'mild',
    /* workoutDurationMin */ 135,
  );
  const hydration = calculatePreWorkoutHydration({
    bodyWeightKg: 72,
    workoutDurationMin: 135,
    timeBeforeWorkoutMin: 180,
    tempC: 22,
  });
  return applyPreWorkoutHydrationOverlay(legacy, hydration);
}

// ---- Example 6 via calculateBrickMacrosV4 -----------------------------------

describe('calculateBrickMacrosV4 — Example 6 integration (bike→run)', () => {
  it('bike and run segments both show replacement_pct 0.60 and hydration_rate ~789', () => {
    // Matches spec Example 6: 72 kg, medium, 27°C, 50%, outdoor, no known rate
    // bike 90 min + run 45 min → total 135 min → replacement_pct = 0.60
    // recommended = 789 ml/hr for both segments
    const input = {
      weight: 72,
      weight_unit: 'kg',
      activity_type: 'brick',
      intensity: 'moderate',
      duration_minutes: 135,
      hours_before: 2,
      is_fasted: false,
      sweat_rate_category: 'medium',
      sweat_sodium: 'average',
      gut_training: 'moderate',
      temp_c: 27,
      humidity_pct: 50,
      is_indoor: false,
      known_sweat_rate_ml_hr: null,
      known_sodium_concentration_mg_l: null,
      brick_segments: [
        {
          sport: 'cycling',
          order: 1,
          duration_minutes: 90,
          intensity: 'moderate',
          speed_mph: 18,
          terrain: 'flat',
          distance_miles: 27,
        },
        {
          sport: 'running',
          order: 2,
          duration_minutes: 45,
          intensity: 'moderate',
          pace_minutes_per_mile: 9,
          distance_miles: 5,
        },
      ],
    } as Parameters<typeof calculateBrickMacrosV4>[0];

    const result = calculateBrickMacrosV4(input, makePreTargets());
    const segs = result.phases.during_segments;

    const bikeSeg = segs.find((s: { sport: string }) => s.sport === 'cycling')!;
    const runSeg  = segs.find((s: { sport: string }) => s.sport === 'running')!;

    // Both segments must share the total-duration replacement %
    assertEquals(bikeSeg.replacement_pct, runSeg.replacement_pct,
      'bike and run share the same replacement_pct');
    assertEquals(bikeSeg.replacement_pct, 0.60,
      'replacement_pct = 0.60 for 135 min brick');

    // Both segments should have hydration_rate_ml_per_h ≈ 789
    const tol = Math.max(5, 789 * 0.05);
    assert(Math.abs(bikeSeg.hydration_rate_ml_per_h - 789) <= tol,
      `bike hydration_rate_ml_per_h expected ~789, got ${bikeSeg.hydration_rate_ml_per_h}`);
    assert(Math.abs(runSeg.hydration_rate_ml_per_h - 789) <= tol,
      `run hydration_rate_ml_per_h expected ~789, got ${runSeg.hydration_rate_ml_per_h}`);

    // water_ml derived from rate × duration
    const expectedBikeWater = Math.round(bikeSeg.hydration_rate_ml_per_h * 90 / 60);
    const expectedRunWater  = Math.round(runSeg.hydration_rate_ml_per_h * 45 / 60);
    assertMlClose(bikeSeg.water_ml, expectedBikeWater, 'bike water_ml from rate×duration');
    assertMlClose(runSeg.water_ml, expectedRunWater, 'run water_ml from rate×duration');

    // The single bike→run gap is T1 (positional, brick.md R8), 300 ml
    const t1 = result.phases.transitions.find((t: { transition_name: string }) =>
      t.transition_name === 'T1')!;
    assertEquals(t1.water_ml, 300, 'T1 water = 300 ml');

    // Carbs are untouched (non-zero for drinkable segments)
    assert(bikeSeg.carbs_g > 0, 'bike carbs preserved');
    assert(runSeg.carbs_g > 0, 'run carbs preserved');
  });

  it('is_tested = false when no known_sweat_rate_ml_hr', () => {
    const input = {
      weight: 72, weight_unit: 'kg', activity_type: 'brick',
      intensity: 'moderate', duration_minutes: 135, hours_before: 2, is_fasted: false,
      sweat_rate_category: 'medium', sweat_sodium: 'average',
      gut_training: 'moderate', temp_c: 27, humidity_pct: 50,
      is_indoor: false, known_sweat_rate_ml_hr: null,
      known_sodium_concentration_mg_l: null,
      brick_segments: [
        { sport: 'cycling', order: 1, duration_minutes: 90, intensity: 'moderate',
          speed_mph: 18, terrain: 'flat', distance_miles: 27 },
        { sport: 'running', order: 2, duration_minutes: 45, intensity: 'moderate',
          pace_minutes_per_mile: 9, distance_miles: 5 },
      ],
    } as Parameters<typeof calculateBrickMacrosV4>[0];

    const result = calculateBrickMacrosV4(input, makePreTargets());
    const bikeSeg = result.phases.during_segments.find((s: { sport: string }) => s.sport === 'cycling')!;
    assertEquals(bikeSeg.is_tested, false, 'is_tested = false without known rate');
  });

  it('is_tested = true when known_sweat_rate_ml_hr provided', () => {
    const input = {
      weight: 68, weight_unit: 'kg', activity_type: 'brick',
      intensity: 'moderate', duration_minutes: 140, hours_before: 2, is_fasted: false,
      sweat_rate_category: 'medium', sweat_sodium: 'average',
      gut_training: 'moderate', temp_c: 26, humidity_pct: 55,
      is_indoor: false, known_sweat_rate_ml_hr: 1300,
      known_sodium_concentration_mg_l: null,
      brick_segments: [
        { sport: 'swimming', order: 1, duration_minutes: 25, intensity: 'moderate',
          distance_meters: 1500 },
        { sport: 'cycling', order: 2, duration_minutes: 65, intensity: 'moderate',
          speed_mph: 25, terrain: 'flat', distance_miles: 27 },
        { sport: 'running', order: 3, duration_minutes: 50, intensity: 'moderate',
          pace_minutes_per_mile: 9, distance_miles: 5.5 },
      ],
    } as Parameters<typeof calculateBrickMacrosV4>[0];

    const result = calculateBrickMacrosV4(input, makePreTargets());
    const bikeSeg = result.phases.during_segments.find((s: { sport: string }) => s.sport === 'cycling')!;
    const runSeg  = result.phases.during_segments.find((s: { sport: string }) => s.sport === 'running')!;
    assertEquals(bikeSeg.is_tested, true, 'bike is_tested = true with known rate');
    assertEquals(runSeg.is_tested, true, 'run is_tested = true with known rate');

    // All drinkable segments share the same replacement_pct (total duration based)
    assertEquals(bikeSeg.replacement_pct, runSeg.replacement_pct,
      'bike and run share replacement_pct');

    // T1 and T2 water = 300 ml each
    const t1 = result.phases.transitions.find((t: { transition_name: string }) =>
      t.transition_name === 'T1')!;
    const t2 = result.phases.transitions.find((t: { transition_name: string }) =>
      t.transition_name === 'T2')!;
    assertEquals(t1.water_ml, 300, 'T1 = 300 ml');
    assertEquals(t2.water_ml, 300, 'T2 = 300 ml');

    // Swim segment: hydration_rate = 0
    const swimSeg = result.phases.during_segments.find((s: { sport: string }) => s.sport === 'swimming')!;
    assertEquals(swimSeg.hydration_rate_ml_per_h, 0, 'swim hydration_rate_ml_per_h = 0');
    assertEquals(swimSeg.water_ml, 0, 'swim water_ml = 0');
  });
});

// ============================================================================
// Transition carb dose — SSOT: docs/ssot/spec/fueling/transition-nutrition.md
// v1 (RATIFIED Xuan 2026-09-01). The spec's worked examples W1–W4; the full
// 10-vector sweep runs Dart-side via qa run_dart.sh transition-nutrition.
// Replaces the retired weight×0.3/0.35 g/kg tiers over a 180-min cliff.
// ============================================================================

describe('Transition carb dose (T-1..T-4)', () => {
  it('W1: bike 60 → run 45, tmin 5 → clamp 30 g', () => {
    const d = calculateTransitionCarbDose(
      [
        { sport: 'cycling', durationMin: 60 },
        { sport: 'running', durationMin: 45 },
      ],
      0, 'moderate', 5,
    );
    // cum 105 → band 45-60 mid 52.5, run ceil 70; gap 15+5+15=35;
    // 52.5×35/60 = 30.625 → 31 → clamp 30
    assertEquals(d.dose_g, 30);
    assertEquals(d.band_low_g, 0);
    assertEquals(d.band_high_g, 30);
  });

  it('W2: run 20 → bike 20, tmin 2 → 7 g (short bricks are nonzero)', () => {
    const d = calculateTransitionCarbDose(
      [
        { sport: 'running', durationMin: 20 },
        { sport: 'cycling', durationMin: 20 },
      ],
      0, 'moderate', 2,
    );
    // cum 40 → band 0-30 mid 15; gap 15+2+10=27; 6.75 → 7
    assertEquals(d.dose_g, 7);
  });

  it('W3: swim extends the gap (T-3) — full swim duration, not pre-buffer', () => {
    const d = calculateTransitionCarbDose(
      [
        { sport: 'swimming', durationMin: 35 },
        { sport: 'cycling', durationMin: 180 },
        { sport: 'running', durationMin: 110 },
      ],
      0, 'moderate', 3,
    );
    // cum through bike 215 → band 60-90 mid 75; gap 35+3+10=48; 60 → clamp 30
    assertEquals(d.dose_g, 30);
    assertEquals(d.effective_gap_min, 48);
  });

  it('W4: any → swim doses 0 (swim ceiling 0; 0 is legitimate)', () => {
    const d = calculateTransitionCarbDose(
      [
        { sport: 'cycling', durationMin: 60 },
        { sport: 'swimming', durationMin: 30 },
      ],
      0, 'moderate', 2,
    );
    assertEquals(d.dose_g, 0);
  });

  it('transition_min defaults to 3 when absent (Q-TN3 ratified default)', () => {
    const d = calculateTransitionCarbDose(
      [
        { sport: 'running', durationMin: 20 },
        { sport: 'cycling', durationMin: 20 },
      ],
      0, 'moderate', null,
    );
    // gap 15+3+10=28; 15×28/60 = 7.0 → 7
    assertEquals(d.dose_g, 7);
    assertEquals(d.transition_min, 3);
  });

  it('macros payload carries the T-1 dose + band, not weight tiers', () => {
    const input = {
      weight: 73, weight_unit: 'kg', activity_type: 'brick',
      hours_before: 2, is_fasted: false, gut_training: 'moderate',
      sweat_rate_category: 'medium', sweat_sodium: 'average',
      brick_segments: [
        { sport: 'cycling', order: 1, duration_minutes: 60, intensity: 'moderate' },
        { sport: 'running', order: 2, duration_minutes: 45, intensity: 'moderate',
          pace_minutes_per_mile: 9 },
      ],
    } as Parameters<typeof calculateBrickMacrosV4>[0];
    const result = calculateBrickMacrosV4(input, makePreTargets());
    const t1 = result.phases.transitions[0];
    assertEquals(t1.transition_name, 'T1');
    assertEquals(t1.sport_pair, 'cycling→running');
    // W1 with the default tmin 3: gap 15+3+15=33; 52.5×33/60=28.875 → 29
    assertEquals(t1.carbs_g, 29);
    assertEquals(t1.carbs_low_g, 0);
    assertEquals(t1.carbs_high_g, 30);
    // The retired tiers would have given 0 here (105 min < 180 cliff)
  });
});
