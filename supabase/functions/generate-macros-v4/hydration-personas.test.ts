/**
 * Hydration & Sodium — Persona × Workout Matrix
 *
 * Follows the pattern from _shared/nutrition/algorithm-audit.test.ts: named
 * personas run through a matrix of workout scenarios. Each test asserts the
 * full expected output shape so we catch regressions in any one of:
 *   - effective sweat rate derivation
 *   - duration-scaled replacement %
 *   - 2% BW floor
 *   - sport GI ceiling
 *   - safety flags
 *   - sodium-rides-on-fluid derivation
 *   - transition and redistribution behaviour
 *   - pre-workout tier overlay
 *
 * Run with:
 *   deno test --allow-all --no-check \\
 *     supabase/functions/generate-macros-v4/hydration-personas.test.ts
 */

import {
  assert,
  assertAlmostEquals,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import {
  calculateDuringWorkoutHydration,
  type DuringWorkoutHydrationInput,
} from './single-sport.ts';
import { calculateBrickHydration } from './brick-workout.ts';
import { calculatePreWorkoutHydration } from './pre-workout.ts';

/** Abs tolerance for exact-ml comparisons. The engine never rounds. */
const TOL_ML = 1e-3;

// ============================================================================
// PERSONAS
// ============================================================================

/**
 * One athlete persona. Intentionally covers a spread of body weight, sweater
 * category, salt category, and test status so the matrix exercises every
 * major branch in the algorithm.
 */
interface Persona {
  id: string;
  label: string;
  weightKg: number;
  sweater: 'light' | 'medium' | 'heavy';
  salt: 'low' | 'average' | 'high';
  knownRateMlHr: number | null;   // non-null = "TESTED ✓"
  knownNaMgL: number | null;
}

const PERSONAS: Record<string, Persona> = {
  // Baseline 50th-percentile runner — the reference athlete in the spec.
  RACHEL: {
    id: 'rachel',
    label: '70 kg medium/average runner (spec reference)',
    weightKg: 70, sweater: 'medium', salt: 'average',
    knownRateMlHr: null, knownNaMgL: null,
  },
  // Featherweight female runner — floor rarely trips, small absolute losses.
  LILA: {
    id: 'lila',
    label: '52 kg light/low — petite, efficient',
    weightKg: 52, sweater: 'light', salt: 'low',
    knownRateMlHr: null, knownNaMgL: null,
  },
  // Heavy age-grouper — heavy sweater, high-salt, prime candidate for
  // floor-exceeds-ceiling warnings in hot races.
  MARCUS: {
    id: 'marcus',
    label: '85 kg heavy/high — big sweater',
    weightKg: 85, sweater: 'heavy', salt: 'high',
    knownRateMlHr: null, knownNaMgL: null,
  },
  // Cyclist who trains indoors year-round — indoor 1.30× almost always on.
  KAI: {
    id: 'kai',
    label: '75 kg medium/average indoor cyclist',
    weightKg: 75, sweater: 'medium', salt: 'average',
    knownRateMlHr: null, knownNaMgL: null,
  },
  // Pro-level triathlete with a LEVELEN sweat test result.
  ZARA: {
    id: 'zara',
    label: '68 kg TESTED (1300 ml/hr, 925 mg/L) triathlete',
    weightKg: 68, sweater: 'medium', salt: 'average',
    knownRateMlHr: 1300, knownNaMgL: 925,
  },
  // Extreme heavy ultra athlete — 100 kg, tests the clamp and ceiling math.
  BJORN: {
    id: 'bjorn',
    label: '100 kg heavy/high ultra athlete',
    weightKg: 100, sweater: 'heavy', salt: 'high',
    knownRateMlHr: null, knownNaMgL: null,
  },
  // Extreme lightweight — 45 kg, tests small BW deficit edges.
  SOFIA: {
    id: 'sofia',
    label: '45 kg light/low runner (extreme lightweight)',
    weightKg: 45, sweater: 'light', salt: 'low',
    knownRateMlHr: null, knownNaMgL: null,
  },
  // Tested heavy sweater — personal sweat rate overrides category.
  DEVIN: {
    id: 'devin',
    label: '80 kg TESTED heavy sweater (1900 ml/hr, 1100 mg/L)',
    weightKg: 80, sweater: 'heavy', salt: 'high',
    knownRateMlHr: 1900, knownNaMgL: 1100,
  },
};

// ============================================================================
// ENVIRONMENTS
// ============================================================================

const ENV_MILD_OUTDOOR = { tempC: 14, humidityPct: 50, isIndoor: false };
const ENV_TEMPERATE    = { tempC: 22, humidityPct: 50, isIndoor: false };
const ENV_WARM         = { tempC: 26, humidityPct: 55, isIndoor: false };
const ENV_HOT          = { tempC: 31, humidityPct: 65, isIndoor: false };
const ENV_EXTREME      = { tempC: 35, humidityPct: 75, isIndoor: false };
const ENV_INDOOR_MILD  = { tempC: 22, humidityPct: 50, isIndoor: true };

// ============================================================================
// SINGLE-SPORT PERSONA × WORKOUT MATRIX
// ============================================================================

interface ExpectedDuring {
  // Required assertions
  minRate?: number;
  maxRate?: number;
  floorMax?: number;
  ceiling?: number;
  gate?: boolean;
  hasFlag?: string;
  replacementPct?: number;
}

function runDuring(
  persona: Persona,
  env: typeof ENV_TEMPERATE,
  sport: 'running' | 'cycling' | 'swimming',
  durationMin: number,
): ReturnType<typeof calculateDuringWorkoutHydration> {
  const input: DuringWorkoutHydrationInput = {
    durationMin,
    weightKg: persona.weightKg,
    sweatRateCategory: persona.sweater,
    sweatSodiumCat: persona.salt,
    tempC: env.tempC,
    humidityPct: env.humidityPct,
    isIndoor: env.isIndoor,
    sport,
    knownSweatRateMlPerHour: persona.knownRateMlHr,
    knownSodiumConcMgPerL: persona.knownNaMgL,
  };
  return calculateDuringWorkoutHydration(input);
}

function checkExpectations(
  result: ReturnType<typeof calculateDuringWorkoutHydration>,
  exp: ExpectedDuring,
  label: string,
) {
  if (exp.minRate !== undefined) {
    assert(result.hydration_rate_mlph >= exp.minRate,
      `${label}: rate ${result.hydration_rate_mlph} < min ${exp.minRate}`);
  }
  if (exp.maxRate !== undefined) {
    assert(result.hydration_rate_mlph <= exp.maxRate,
      `${label}: rate ${result.hydration_rate_mlph} > max ${exp.maxRate}`);
  }
  if (exp.ceiling !== undefined) {
    assertEquals(result.ceiling_ml_hr, exp.ceiling,
      `${label}: ceiling mismatch`);
  }
  if (exp.gate !== undefined) {
    const gateFired = result.safety_flags.includes('No structured hydration plan needed. Drink to thirst and hydrate before and immediately after.');
    assertEquals(gateFired, exp.gate, `${label}: gate expected=${exp.gate}`);
  }
  if (exp.hasFlag) {
    assert(
      result.safety_flags.some(f => f.includes(exp.hasFlag!)),
      `${label}: missing safety flag containing "${exp.hasFlag}" (got: ${JSON.stringify(result.safety_flags)})`,
    );
  }
  if (exp.replacementPct !== undefined) {
    assertEquals(result.replacement_pct, exp.replacementPct,
      `${label}: replacement_pct mismatch`);
  }
  // Sodium always = round((fluid_ml_hr / 1000) × conc)
  const expectedSodium = Math.round(
    (result.hydration_rate_mlph / 1000) * result.sodium_conc_mg_per_l,
  );
  assertEquals(result.sodium_rate_mgph, expectedSodium,
    `${label}: sodium should equal fluid × conc / 1000`);
}

// ─── Matrix definitions ──────────────────────────────────────────────────────

/** Workout scenarios exercised against every persona. */
const SCENARIOS: Array<{
  id: string;
  label: string;
  sport: 'running' | 'cycling' | 'swimming';
  durationMin: number;
  env: typeof ENV_TEMPERATE;
  expect: (p: Persona) => ExpectedDuring;
}> = [
  {
    id: 'speedwork',
    label: '45-min speedwork in mild weather (gate should fire)',
    sport: 'running', durationMin: 45, env: ENV_TEMPERATE,
    expect: () => ({ gate: true, replacementPct: 0.30, ceiling: undefined }),
  },
  {
    id: 'tempo-60',
    label: '60-min tempo run at 22°C (no gate, 50% replacement)',
    sport: 'running', durationMin: 60, env: ENV_TEMPERATE,
    expect: () => ({ gate: false, replacementPct: 0.50 }),
  },
  {
    id: 'long-run-cool',
    label: '90-min long run on cool morning',
    sport: 'running', durationMin: 90, env: ENV_MILD_OUTDOOR,
    expect: () => ({ gate: false, replacementPct: 0.50, ceiling: undefined }),
  },
  {
    id: 'hilly-century',
    label: '3-hour cycling at 31°C — potential floor > ceiling',
    sport: 'cycling', durationMin: 180, env: ENV_HOT,
    expect: (p) => ({
      gate: false, replacementPct: 0.70, ceiling: undefined,
      // Heavy personas in heat should flag BW-loss warning
      hasFlag: p.sweater === 'heavy' ? 'exceed 2% BW' : undefined,
    }),
  },
  {
    id: 'indoor-trainer',
    label: '60-min indoor trainer at 22°C (1.30× indoor mult)',
    sport: 'cycling', durationMin: 60, env: ENV_INDOOR_MILD,
    // Ceiling = min(1200, effective * 1000). For light sweaters at indoor
    // 22°C effective < 1.2 L/hr, so ceiling ends up being 100% of sweat rate
    // rather than the cycling GI cap. Just assert replacement_pct.
    expect: () => ({ gate: false, replacementPct: 0.50 }),
  },
  {
    id: 'marathon',
    label: '3h15 marathon at 26°C warm',
    sport: 'running', durationMin: 195, env: ENV_WARM,
    expect: () => ({ gate: false, replacementPct: 0.70 }),
  },
  {
    id: 'ultra',
    label: '5-hour ultra in hot conditions',
    sport: 'running', durationMin: 300, env: ENV_HOT,
    expect: () => ({ gate: false, replacementPct: 0.80 }),
  },
  {
    id: 'short-hot-hill',
    label: '45-min hill reps at 31°C (gate bypassed by heat)',
    sport: 'running', durationMin: 45, env: ENV_HOT,
    expect: () => ({ gate: false, replacementPct: 0.30 }),
  },
  {
    id: 'swim-only',
    label: '30-min pool swim (cannot drink)',
    sport: 'swimming', durationMin: 30, env: ENV_TEMPERATE,
    expect: () => ({ maxRate: 0 }),
  },
];

describe('Persona × Workout matrix — single-sport hydration', () => {
  for (const persona of Object.values(PERSONAS)) {
    for (const scenario of SCENARIOS) {
      it(`${persona.id} × ${scenario.id}: ${scenario.label}`, () => {
        const result = runDuring(
          persona, scenario.env, scenario.sport, scenario.durationMin,
        );
        checkExpectations(
          result,
          scenario.expect(persona),
          `${persona.id}/${scenario.id}`,
        );

        // Universal invariants that every output must satisfy
        assert(result.effective_sweat_rate_lph >= 0.3,
          `effective sweat rate below clamp for ${persona.id}/${scenario.id}`);
        assert(result.effective_sweat_rate_lph <= 3.0,
          `effective sweat rate above clamp for ${persona.id}/${scenario.id}`);
        assert(result.hydration_rate_mlph >= 0,
          `fluid rate negative for ${persona.id}/${scenario.id}`);
        assert(Number.isFinite(result.hydration_rate_mlph),
          `fluid rate NaN for ${persona.id}/${scenario.id}`);
        assert(Number.isFinite(result.sodium_rate_mgph),
          `sodium rate NaN for ${persona.id}/${scenario.id}`);

        // is_tested should agree with persona setup
        assertEquals(result.is_tested, persona.knownRateMlHr !== null,
          `is_tested mismatch for ${persona.id}`);

        // Breakdown fields must be populated
        assert(result.base_sweat_rate_lph > 0, 'base_sweat_rate_lph populated');
        assert(typeof result.replacement_band === 'string',
          'replacement_band populated');
      });
    }
  }
});

// ============================================================================
// HEAVY SCENARIO ASSERTIONS — full numeric expectations
// ============================================================================

describe('Numeric expectations — Marcus (heavy sweater) in heat', () => {
  it('180 min cycling at 31°C → floor > ceiling flag and deficit flag', () => {
    const result = runDuring(PERSONAS.MARCUS, ENV_HOT, 'cycling', 180);
    // effective = 1.66 × 1.36 × 1.03 ≈ 2.33 L/hr
    // Marcus is 85 kg: max_deficit = 1700 ml
    // total_loss = 2325 × 3 = 6975 ml
    // floor = (6975 - 1700)/3 ≈ 1758 ml/hr
    // ceiling = min(1200, 2325) = 1200 → ceiling < floor
    assertEquals(result.ceiling_ml_hr, 1200);
    assert(result.floor_ml_hr >= 1700,
      `floor should exceed cycling GI ceiling, got ${result.floor_ml_hr}`);
    assertEquals(result.hydration_rate_mlph, 1200, 'capped at ceiling');
    assert(result.safety_flags.some(f => f.includes('maximum intake')),
      'ceiling<floor flag present');
    assert(result.safety_flags.some(f => f.includes('Significant dehydration')),
      'deficit >3% flag present');
  });
});

describe('Numeric expectations — Zara (tested triathlete)', () => {
  it('90-min run with known rate 1300 and known Na 925 → exact sodium', () => {
    const result = runDuring(PERSONAS.ZARA, ENV_WARM, 'running', 90);
    // effective = 1.30 × 1.16 × 1.01 ≈ 1.52 L/hr, is_tested=true
    // replacement = 0.50 at 90 min
    // pct-based = 1520 × 0.50 = 760
    // ceiling = min(800, 1520) = 800 → no cap
    // Marcus floor: total_loss = 1520 × 1.5 = 2280; max_deficit = 1360; floor = (2280-1360)/1.5 = 613
    // 760 > 613 → no floor override → fluid_rate = 760
    assertEquals(result.is_tested, true);
    assert(result.hydration_rate_mlph >= 740 && result.hydration_rate_mlph <= 780,
      `expected ~760, got ${result.hydration_rate_mlph}`);
    // sodium = (fluid/1000) × 925; with known_conc = 925 overrides category
    assertEquals(result.sodium_conc_mg_per_l, 925);
    const expectedNa = Math.round((result.hydration_rate_mlph / 1000) * 925);
    assertEquals(result.sodium_rate_mgph, expectedNa);
  });
});

describe('Numeric expectations — Sofia (extreme lightweight)', () => {
  it('90-min long run at mild temp → floor=0, ceiling=612, rate=306', () => {
    // Matches spec Example 2 with 45 kg (spec used 65 kg). Ratios preserved.
    const result = runDuring(PERSONAS.SOFIA, ENV_MILD_OUTDOOR, 'running', 90);
    // effective = 0.90 × 0.68 = 0.612 L/hr
    // total_loss = 918 ml; max_deficit = 900 ml; floor = (918-900)/1.5 = 12 ml/hr
    // pct = 612 × 0.50 = 306 ml/hr; ceiling = min(800, 612) = 612
    // 306 > 12 → no floor override → 306 ml/hr
    assertEquals(result.hydration_rate_mlph, 306);
    assertEquals(result.ceiling_ml_hr, 612);
    assert(result.floor_ml_hr <= 20,
      `floor should be small for lightweight, got ${result.floor_ml_hr}`);
  });
});

describe('Numeric expectations — Kai (75 kg indoor cyclist)', () => {
  it('60-min indoor at 22°C → effective = 1.28 × 1.30 = 1.664 L/hr', () => {
    const result = runDuring(PERSONAS.KAI, ENV_INDOOR_MILD, 'cycling', 60);
    assert(
      Math.abs(result.effective_sweat_rate_lph - 1.664) < 0.02,
      `expected ~1.66 effective L/hr, got ${result.effective_sweat_rate_lph}`,
    );
    assertEquals(result.indoor_mult, 1.30);
    // 1664 × 0.50 = 832 ml/hr
    assert(
      Math.abs(result.hydration_rate_mlph - 832) <= 42,
      `expected ~832 ml/hr, got ${result.hydration_rate_mlph}`,
    );
  });
});

// ============================================================================
// BRICK / REDISTRIBUTION MATRIX
// ============================================================================

describe('Brick / triathlon × persona matrix', () => {
  const tests: Array<{
    persona: Persona;
    label: string;
    segments: Array<{ sport: string; durationMin: number; order: number }>;
    env: typeof ENV_TEMPERATE;
    expectRedistribution?: boolean;
    expectBikeRate?: number;
    expectRunRate?: number;
  }> = [
    {
      persona: PERSONAS.ZARA,
      label: 'Olympic tri (tested) — 25/65/50',
      segments: [
        { sport: 'swimming', durationMin: 25, order: 1 },
        { sport: 'cycling',  durationMin: 65, order: 2 },
        { sport: 'running',  durationMin: 50, order: 3 },
      ],
      env: ENV_WARM,
      expectRedistribution: false,
    },
    {
      persona: PERSONAS.RACHEL,
      label: 'Brick bike+run — 90/45 warm',
      segments: [
        { sport: 'cycling', durationMin: 90, order: 1 },
        { sport: 'running', durationMin: 45, order: 2 },
      ],
      env: ENV_WARM,
      expectRedistribution: false,
    },
    {
      persona: PERSONAS.BJORN,
      label: 'Iron-distance bike+run at 31°C — heavy, expect redistribution',
      segments: [
        { sport: 'cycling', durationMin: 240, order: 1 },
        { sport: 'running', durationMin: 180, order: 2 },
      ],
      env: ENV_HOT,
      expectRedistribution: true,
    },
    {
      persona: PERSONAS.MARCUS,
      label: 'Short brick 60/60 in extreme heat — redistribution expected',
      segments: [
        { sport: 'cycling', durationMin: 60, order: 1 },
        { sport: 'running', durationMin: 60, order: 2 },
      ],
      env: ENV_EXTREME,
      expectRedistribution: true,
    },
    {
      persona: PERSONAS.LILA,
      label: 'Sprint tri 10/30/20 at 22°C — small athlete, no flags',
      segments: [
        { sport: 'swimming', durationMin: 10, order: 1 },
        { sport: 'cycling',  durationMin: 30, order: 2 },
        { sport: 'running',  durationMin: 20, order: 3 },
      ],
      env: ENV_TEMPERATE,
      expectRedistribution: false,
    },
  ];

  for (const t of tests) {
    it(`${t.persona.id}: ${t.label}`, () => {
      const result = calculateBrickHydration({
        weightKg: t.persona.weightKg,
        segments: t.segments,
        sweatRateCategory: t.persona.sweater,
        sweatSodiumCat: t.persona.salt,
        tempC: t.env.tempC,
        humidityPct: t.env.humidityPct,
        isIndoor: t.env.isIndoor,
        knownSweatRateMlPerHour: t.persona.knownRateMlHr,
        knownSodiumConcMgPerL: t.persona.knownNaMgL,
      });

      // Every swim segment has 0 rate
      for (const seg of result.segments) {
        if (seg.sport.toLowerCase() === 'swimming') {
          assertEquals(seg.hydration_rate_mlph, 0, 'swim rate = 0');
          assertEquals(seg.sodium_rate_mgph, 0, 'swim sodium = 0');
        } else {
          assert(
            seg.hydration_rate_mlph >= 0,
            `${seg.sport} rate must be non-negative`,
          );
          // Sodium rides on fluid
          const expectedNa = Math.round(
            (seg.hydration_rate_mlph / 1000) * result.sodium_conc_mg_per_l,
          );
          assertEquals(seg.sodium_rate_mgph, expectedNa,
            `${seg.sport} sodium must equal fluid × conc / 1000`);
        }
      }

      // Every transition sodium = (300/1000) × conc (NO 0.3 factor)
      const expectedTransitionNa = Math.round(
        (300 / 1000) * result.sodium_conc_mg_per_l,
      );
      for (const trans of result.transitions) {
        assertEquals(trans.water_ml, 300, 'transition water fixed at 300');
        assertEquals(trans.sodium_mg, expectedTransitionNa,
          `transition sodium must be ${expectedTransitionNa}`);
      }

      // Redistribution flag expectation
      const hasRedistFlag = result.safety_flags.some(f =>
        f.includes('maximum intake on all segments')
      );
      if (t.expectRedistribution) {
        assert(hasRedistFlag,
          `expected redistribution flag, got flags=${JSON.stringify(result.safety_flags)}`);
      }
    });
  }
});

// ============================================================================
// PRE-WORKOUT HYDRATION v6 x PERSONA MATRIX
// ============================================================================
//
// The v1 block that lived here asserted an integer `tier`, a flat 6 ml/kg
// target with a 5-7 ml/kg band, a fixed 250 ml "tier 2" and 450/150/0 mg of
// sodium. Every one of those is now wrong and `tier` no longer exists, so the
// block was deleted rather than adapted. What replaces it asserts the SSOT v6
// shape -- regime, target_basis and the exact per-persona fluid numbers -- and
// sodium v3's strict nulls.
//
// Ratified NUMBERS are pinned once, in pre-workout-vectors.test.ts. What this
// matrix adds is body-weight coverage: the personas span 45-100 kg, which
// straddles the A0 = min(250, 7.5*BW) guard and the clearance ceiling.

describe('Pre-workout hydration v6 x persona matrix', () => {
  /** f(x) = A0 + (7.5*BW - A0) * min(x, 120)/120 -- the spec's taper. */
  function taper(bw: number, x: number): number {
    const a0 = Math.min(250, 7.5 * bw);
    return a0 + (7.5 * bw - a0) * Math.min(x, 120) / 120;
  }

  const cases = [
    // t >= 120 -> cited/evidenced_band, plan = 7.5*BW (pale/unknown).
    { minsBefore: 240, workoutMin: 180, temp: 22, gate: false, regime: 'cited' },
    { minsBefore: 120, workoutMin: 120, temp: 22, gate: false, regime: 'cited' },
    // 30 <= t < 120 -> extrapolated/design_choice, plan = f(t) in the snack tier.
    { minsBefore: 90, workoutMin: 120, temp: 22, gate: false, regime: 'extrapolated' },
    { minsBefore: 30, workoutMin: 120, temp: 22, gate: false, regime: 'extrapolated' },
    // t < 30 -> top-off only. At t = 10 the clearance ceiling still exceeds
    // 10*BW for every persona at or under 90 kg, so the regime is per-persona
    // and derived below rather than asserted as a constant.
    { minsBefore: 10, workoutMin: 120, temp: 22, gate: false, regime: null },
    { minsBefore: 5, workoutMin: 120, temp: 22, gate: false, regime: null },
    // Gate: 45 min in mild weather. Lead time is irrelevant to the gate.
    { minsBefore: 240, workoutMin: 45, temp: 22, gate: true, regime: 'gated' },
    { minsBefore: 90, workoutMin: 45, temp: 22, gate: true, regime: 'gated' },
    // Gate bypassed at 30 C+.
    { minsBefore: 240, workoutMin: 45, temp: 31, gate: false, regime: 'cited' },
  ];

  for (
    const persona of [
      PERSONAS.RACHEL,
      PERSONAS.LILA,
      PERSONAS.MARCUS,
      PERSONAS.BJORN,
      PERSONAS.SOFIA,
    ]
  ) {
    for (const tc of cases) {
      it(`${persona.id}: t-${tc.minsBefore}, dur=${tc.workoutMin} min, ${tc.temp} C`, () => {
        const bw = persona.weightKg;
        const result = calculatePreWorkoutHydration({
          bodyWeightKg: bw,
          workoutDurationMin: tc.workoutMin,
          timeBeforeWorkoutMin: tc.minsBefore,
          tempC: tc.temp,
        });

        assertEquals(result.gate_triggered, tc.gate, `gate for ${persona.id}`);
        if (tc.regime !== null) {
          assertEquals(result.regime, tc.regime, `regime for ${persona.id}`);
        }

        // Sodium v3 -- null on EVERY path, gated or not. Strict: a 0 fails.
        assertEquals(result.sodium_mg, null, `${persona.id}: sodium_mg`);
        assertEquals(result.sodium_low_mg, null, `${persona.id}: sodium_low_mg`);
        assertEquals(result.sodium_high_mg, null, `${persona.id}: sodium_high_mg`);

        if (tc.gate) {
          // null, not 0 -- the gate makes no statement.
          assertEquals(result.fluid_ml, null, `${persona.id}: gated fluid_ml`);
          assertEquals(result.fluid_low_ml, null);
          assertEquals(result.fluid_high_ml, null);
          assertEquals(result.tiers.length, 0, 'gate emits no tiers');
          assertEquals(result.target_basis, 'none');
          assertEquals(result.hydration_check_used, null);
          return;
        }

        assertEquals(result.target_basis,
          tc.minsBefore >= 120 ? 'evidenced_band' : 'design_choice');

        if (tc.minsBefore >= 120) {
          // unknown normalises to pale above T_REF -> no dark top-up.
          assertAlmostEquals(result.fluid_ml!, 7.5 * bw, TOL_ML, `${persona.id}: plan`);
          assertAlmostEquals(result.fluid_low_ml!, 5 * bw, TOL_ML, `${persona.id}: low`);
          // min(7.5 + 5, 12) * BW -> the 12 ml/kg plan cap binds.
          assertAlmostEquals(result.fluid_high_ml!, 12 * bw, TOL_ML, `${persona.id}: high`);
          assertEquals(result.hydration_check_used, 'pale');
          assertEquals(result.tiers.map((t) => t.tier), ['meal', 'snack', 'top_off']);
        } else {
          assertAlmostEquals(result.fluid_ml!, taper(bw, tc.minsBefore), TOL_ML,
            `${persona.id}: taper`);
          // Below two hours there is no minimum -- 0, not null.
          assertEquals(result.fluid_low_ml, 0, `${persona.id}: low is 0, not null`);
          const ceiling = 400 * Math.exp((3.2 / 60) * tc.minsBefore);
          assertAlmostEquals(result.fluid_high_ml!, Math.min(10 * bw, ceiling), TOL_ML,
            `${persona.id}: high`);
          assertEquals(result.regime,
            ceiling < 10 * bw ? 'clearance_bound' : 'extrapolated');
          // Below T_REF the echo is RAW -- never normalised.
          assertEquals(result.hydration_check_used, 'unknown');
          assertEquals(result.tiers.map((t) => t.tier),
            tc.minsBefore >= 30 ? ['snack', 'top_off'] : ['top_off']);
        }

        // Fluid never splits: all of it lands in the earliest tier that exists.
        const sum = result.tiers.reduce((a, t) => a + t.fluid_ml, 0);
        assertAlmostEquals(sum, result.fluid_ml!, TOL_ML, `${persona.id}: tiers sum`);
        assertAlmostEquals(result.tiers[0].fluid_ml, result.fluid_ml!, TOL_ML,
          `${persona.id}: all fluid in the earliest tier`);
      });
    }
  }
});

// ============================================================================
// GLOBAL INVARIANTS — sweep the matrix, assert safety properties
// ============================================================================

describe('Global invariants across persona × workout sweeps', () => {
  it('every single-sport output: sodium = round((fluid/1000) × conc)', () => {
    const durations = [45, 60, 90, 135, 180, 300];
    const envs = [ENV_MILD_OUTDOOR, ENV_TEMPERATE, ENV_WARM, ENV_HOT];
    const sports: Array<'running' | 'cycling'> = ['running', 'cycling'];

    let checked = 0;
    for (const persona of Object.values(PERSONAS)) {
      for (const env of envs) {
        for (const sport of sports) {
          for (const dur of durations) {
            const result = runDuring(persona, env, sport, dur);
            const expected = Math.round(
              (result.hydration_rate_mlph / 1000) * result.sodium_conc_mg_per_l,
            );
            assertEquals(result.sodium_rate_mgph, expected,
              `${persona.id}/${sport}/${dur}min @ ${env.tempC}°C: sodium derivation`);
            checked++;
          }
        }
      }
    }
    // Sanity: the sweep actually ran
    assert(checked >= 200, `only checked ${checked} combos`);
  });

  it('brick transition sodium always = round((300/1000) × conc), never × 0.3', () => {
    const segmentSets = [
      [
        { sport: 'swimming', durationMin: 25, order: 1 },
        { sport: 'cycling',  durationMin: 65, order: 2 },
        { sport: 'running',  durationMin: 50, order: 3 },
      ],
      [
        { sport: 'cycling', durationMin: 90, order: 1 },
        { sport: 'running', durationMin: 45, order: 2 },
      ],
      [
        { sport: 'cycling', durationMin: 240, order: 1 },
        { sport: 'running', durationMin: 180, order: 2 },
      ],
    ];
    const envs = [ENV_TEMPERATE, ENV_WARM, ENV_HOT];
    let checked = 0;

    for (const persona of Object.values(PERSONAS)) {
      for (const env of envs) {
        for (const segs of segmentSets) {
          const result = calculateBrickHydration({
            weightKg: persona.weightKg,
            segments: segs,
            sweatRateCategory: persona.sweater,
            sweatSodiumCat: persona.salt,
            tempC: env.tempC,
            humidityPct: env.humidityPct,
            isIndoor: env.isIndoor,
            knownSweatRateMlPerHour: persona.knownRateMlHr,
            knownSodiumConcMgPerL: persona.knownNaMgL,
          });
          const expectedNa = Math.round(
            (300 / 1000) * result.sodium_conc_mg_per_l,
          );
          for (const t of result.transitions) {
            assertEquals(t.sodium_mg, expectedNa,
              `${persona.id} ${env.tempC}°C ${t.transition_name}: ` +
              `expected ${expectedNa} mg, got ${t.sodium_mg}`);
            checked++;
          }
        }
      }
    }
    assert(checked >= 40, `expected many transitions, got ${checked}`);
  });
});
