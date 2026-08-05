/**
 * Pre-workout SSOT conformance — the TypeScript half of the cross-engine pin.
 *
 * Runs the SAME ratified golden vectors the Dart harness runs
 * (`docs/ssot/conformance/pre_workout_*_conformance_test.dart`) through the
 * edge function's engine:
 *
 *   docs/ssot/vectors/fueling/pre-workout-hydration.json   (21 vectors, v6)
 *   docs/ssot/vectors/fueling/pre-workout-carbs.json       (19 vectors, v2)
 *   docs/ssot/vectors/fueling/pre-workout-sodium.json       (8 vectors, v3)
 *
 * WHY THIS FILE EXISTS
 * --------------------
 * The Dart offline calculator and this Deno engine are two independent
 * implementations of one spec, and they have silently drifted apart twice:
 *   1. the tier threshold split (Dart 2.5 h / 1.0 h vs TS 1.5 h / 0.5 h), and
 *   2. the gate-path band (one returned a band, the other returned nothing).
 * Both drifts survived because each side had its own hand-written expectations.
 * Pinning BOTH engines to the same JSON is the only thing that makes a drift
 * fail somewhere. Do not replace these with locally-written numbers — if a
 * vector looks wrong, the fix goes in the SSOT repo, never here.
 *
 * CONTRACT NOTES (mirrored from the Dart harness, deliberately):
 *   - the engine NEVER rounds — compare with abs tolerance 1e-3
 *   - the comparison is NULL-AWARE: a 0 where null is expected FAILS, and a
 *     null where 0 is expected FAILS. `null` = "no statement is made";
 *     `0` = "the answer is zero". Conflating them is the exact failure mode
 *     the gate path and sodium v3 have to be protected against.
 *   - the integer `tier` field is RETIRED and is never read
 *   - vector JSON is camelCase (`fluidMl`); the TS result is snake_case
 *     (`fluid_ml`). The mapping lives in ONE place per slice, below.
 *
 * Run with:
 *   deno test --allow-read --node-modules-dir=none \
 *     supabase/functions/generate-macros-v4/pre-workout-vectors.test.ts
 */

import {
  assert,
  assertAlmostEquals,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import {
  calculatePreWorkoutCarbs,
  calculatePreWorkoutHydration,
  type HydrationCheck,
} from './pre-workout.ts';

// ---------------------------------------------------------------------------
// Vector loading
// ---------------------------------------------------------------------------

/** Abs tolerance for every numeric comparison (the vectors' own default). */
const TOL = 1e-3;

const VECTOR_DIR = new URL(
  '../../../docs/ssot/vectors/fueling/',
  import.meta.url,
);

interface VectorDoc {
  section: string;
  specVersion: string;
  toleranceMl?: number;
  toleranceG?: number;
  vectors: Vector[];
}

interface Vector {
  id: string;
  status?: string;
  inputs: Record<string, unknown>;
  expected: Record<string, unknown>;
  why?: string;
}

function loadVectors(slice: string): VectorDoc {
  const path = new URL(`pre-workout-${slice}.json`, VECTOR_DIR);
  const doc = JSON.parse(Deno.readTextFileSync(path)) as VectorDoc;
  assert(
    Array.isArray(doc.vectors) && doc.vectors.length > 0,
    `pre-workout-${slice}.json carries no vectors — the SSOT sync is broken`,
  );
  return doc;
}

const HYDRATION = loadVectors('hydration');
const CARBS = loadVectors('carbs');
const SODIUM = loadVectors('sodium');

// ---------------------------------------------------------------------------
// Null-aware comparison helpers
// ---------------------------------------------------------------------------

/**
 * Compare one numeric field against its expectation, honouring null.
 *
 * `expected === null` demands an actual `null`; a `0` fails. `expected` a
 * number demands a number within TOL; a `null` fails. Keys absent from the
 * vector's `expected` object are not asserted (each vector pins only what it
 * claims to pin — same rule as the Dart harness).
 */
function chkNullableNum(
  expected: Record<string, unknown>,
  key: string,
  actual: number | null | undefined,
  ctx: string,
): void {
  if (!(key in expected)) return;
  const want = expected[key];
  if (want === null) {
    assertEquals(
      actual,
      null,
      `${ctx}: ${key} must be null (no statement made), got ${actual}`,
    );
    return;
  }
  assert(
    typeof actual === 'number',
    `${ctx}: ${key} must be ${want}, got ${actual}`,
  );
  assertAlmostEquals(
    actual as number,
    want as number,
    TOL,
    `${ctx}: ${key} (abs tol ${TOL})`,
  );
}

function chkExact(
  expected: Record<string, unknown>,
  key: string,
  actual: unknown,
  ctx: string,
): void {
  if (!(key in expected)) return;
  assertEquals(actual, expected[key], `${ctx}: ${key}`);
}

function ctxOf(slice: string, v: Vector): string {
  return `[${slice}] ${v.id}${v.why ? ` — ${v.why}` : ''}`;
}

// ---------------------------------------------------------------------------
// Slice 1 — hydration v6 (21 vectors)
// ---------------------------------------------------------------------------

describe(
  `pre-workout hydration conformance — ${HYDRATION.specVersion} ` +
    `(${HYDRATION.vectors.length} vectors)`,
  () => {
    for (const v of HYDRATION.vectors) {
      it(`[${v.status ?? 'ratified'}] ${v.id}`, () => {
        const ctx = ctxOf('hydration', v);
        const i = v.inputs;
        const out = calculatePreWorkoutHydration({
          bodyWeightKg: i.bodyWeightKg as number,
          workoutDurationMin: i.workoutDurationMin as number,
          timeBeforeWorkoutMin: i.timeBeforeWorkoutMin as number,
          // `tempC: null` is a real input value (defaults to 22 inside the
          // engine), NOT an omission — `gate-tempnull-default` pins it.
          tempC: (i.tempC ?? null) as number | null,
          hydrationCheck: (i.hydrationCheck ?? 'unknown') as HydrationCheck,
        });

        chkExact(v.expected, 'gateTriggered', out.gate_triggered, ctx);
        chkNullableNum(v.expected, 'fluidMl', out.fluid_ml, ctx);
        chkNullableNum(v.expected, 'fluidLowMl', out.fluid_low_ml, ctx);
        chkNullableNum(v.expected, 'fluidHighMl', out.fluid_high_ml, ctx);
        chkExact(v.expected, 'regime', out.regime, ctx);
        chkExact(v.expected, 'targetBasis', out.target_basis, ctx);
        chkExact(
          v.expected,
          'hydrationCheckUsed',
          out.hydration_check_used,
          ctx,
        );

        // The gate vectors omit `hydrationCheckUsed`; the contract says null.
        if (
          !('hydrationCheckUsed' in v.expected) &&
          v.expected.gateTriggered === true
        ) {
          assertEquals(
            out.hydration_check_used,
            null,
            `${ctx}: hydrationCheckUsed must be null on the gate path`,
          );
        }

        // Invariant 11 — gate path emits an EMPTY tiers array, never a
        // zero-valued tier. Invariant 2 — otherwise the tiers sum to the plan.
        if (out.gate_triggered) {
          assertEquals(
            out.tiers.length,
            0,
            `${ctx}: the gate path emits no tiers (inv 11)`,
          );
        } else {
          const sum = out.tiers.reduce((a, t) => a + t.fluid_ml, 0);
          assertAlmostEquals(
            sum,
            out.fluid_ml as number,
            TOL,
            `${ctx}: sum(tiers[].fluid_ml)=${sum} must equal fluid_ml=${out.fluid_ml} (inv 2)`,
          );
          for (const t of out.tiers) {
            assert(
              ['meal', 'snack', 'top_off'].includes(t.tier),
              `${ctx}: unexpected tier name "${t.tier}"`,
            );
          }
        }

        // The integer `tier` is RETIRED — its absence is part of the contract.
        assert(
          !('tier' in (out as unknown as Record<string, unknown>)),
          `${ctx}: the integer \`tier\` field is retired (PW-013) and must not reappear`,
        );
      });
    }
  },
);

// ---------------------------------------------------------------------------
// Slice 2 — carbohydrate v2 (19 vectors)
// ---------------------------------------------------------------------------

describe(
  `pre-workout carbs conformance — ${CARBS.specVersion} ` +
    `(${CARBS.vectors.length} vectors)`,
  () => {
    for (const v of CARBS.vectors) {
      it(`[${v.status ?? 'ratified'}] ${v.id}`, () => {
        const ctx = ctxOf('carbs', v);
        const i = v.inputs;
        const out = calculatePreWorkoutCarbs({
          bodyWeightKg: i.bodyWeightKg as number,
          timeBeforeWorkoutMin: i.timeBeforeWorkoutMin as number,
          workoutDurationMin: i.workoutDurationMin as number,
          isFasted: (i.isFasted ?? false) as boolean,
        });

        chkNullableNum(v.expected, 'carbsG', out.carbs_g, ctx);
        chkNullableNum(v.expected, 'carbsLowG', out.carbs_low_g, ctx);
        chkNullableNum(v.expected, 'carbsHighG', out.carbs_high_g, ctx);
        chkExact(v.expected, 'targetBasis', out.target_basis, ctx);

        if ('tiers' in v.expected) {
          const want = v.expected.tiers as Array<Record<string, unknown>>;
          // Tier ORDER is contractual — furthest-out first.
          assertEquals(
            out.tiers.map((t) => t.tier),
            want.map((t) => t.tier),
            `${ctx}: tier names/order`,
          );
          for (let n = 0; n < want.length; n++) {
            const w = want[n];
            const g = out.tiers[n];
            const tctx = `${ctx} tier[${n}]=${w.tier}`;
            assertAlmostEquals(
              g.carbs_g,
              w.carbsG as number,
              TOL,
              `${tctx}: carbs_g`,
            );
            assertAlmostEquals(
              g.range_low_g,
              w.rangeLowG as number,
              TOL,
              `${tctx}: range_low_g (solver tolerance, not the plan band)`,
            );
            assertAlmostEquals(
              g.range_high_g,
              w.rangeHighG as number,
              TOL,
              `${tctx}: range_high_g (solver tolerance, not the plan band)`,
            );
            // `composition` is contractually a pass-through of `tier` until
            // spec/fueling/pre-workout-food-composition.md lands.
            assertEquals(g.composition, w.composition, `${tctx}: composition`);
          }

          // Invariant — the tier portions sum to the plan total.
          const sum = out.tiers.reduce((a, t) => a + t.carbs_g, 0);
          assertAlmostEquals(
            sum,
            out.carbs_g,
            TOL,
            `${ctx}: sum(tiers[].carbs_g)=${sum} must equal carbs_g=${out.carbs_g}`,
          );
        }
      });
    }
  },
);

// ---------------------------------------------------------------------------
// Slice 3 — sodium v3 (8 vectors)
// ---------------------------------------------------------------------------

describe(
  `pre-workout sodium conformance — ${SODIUM.specVersion} ` +
    `(${SODIUM.vectors.length} vectors)`,
  () => {
    for (const v of SODIUM.vectors) {
      it(`[${v.status ?? 'ratified'}] ${v.id}`, () => {
        const ctx = ctxOf('sodium', v);
        const i = v.inputs;
        const out = calculatePreWorkoutHydration({
          bodyWeightKg: i.bodyWeightKg as number,
          workoutDurationMin: i.workoutDurationMin as number,
          timeBeforeWorkoutMin: i.timeBeforeWorkoutMin as number,
          tempC: (i.tempC ?? null) as number | null,
          hydrationCheck: (i.hydrationCheck ?? 'unknown') as HydrationCheck,
        });

        // Strict null. A `0` here is a conformance FAILURE, not a near-miss:
        // zero is a recommendation ("consume no sodium"); null means Mealvana
        // sets no pre-workout sodium target at all.
        for (
          const [key, actual] of [
            ['sodiumMg', out.sodium_mg],
            ['sodiumLowMg', out.sodium_low_mg],
            ['sodiumHighMg', out.sodium_high_mg],
          ] as const
        ) {
          assertEquals(v.expected[key], null, `${ctx}: vector must expect null`);
          assertEquals(
            actual,
            null,
            `${ctx}: ${key} must be null, got ${actual} ` +
              `(0 is a failure — see pre-workout-sodium.md v3)`,
          );
        }
      });
    }
  },
);

// ---------------------------------------------------------------------------
// Cross-slice pins
// ---------------------------------------------------------------------------

describe('pre-workout cross-slice pins', () => {
  it('no input perturbs sodium — swept, not just the 8 vectors', () => {
    // sodium v3: "No input — body weight, duration, temperature, lead time,
    // tier, hydrationCheck — changes any of the three."
    for (const bw of [30, 50, 65, 90, 120]) {
      for (const t of [0, 15, 30, 60, 119, 120, 180, 240]) {
        for (const dur of [30, 45, 60, 90, 240]) {
          for (const temp of [null, 5, 22, 29, 30, 40]) {
            for (
              const check of ['pale', 'dark', 'unknown'] as HydrationCheck[]
            ) {
              const out = calculatePreWorkoutHydration({
                bodyWeightKg: bw,
                workoutDurationMin: dur,
                timeBeforeWorkoutMin: t,
                tempC: temp,
                hydrationCheck: check,
              });
              const where =
                `BW=${bw} t=${t} dur=${dur} temp=${temp} check=${check}`;
              assertEquals(out.sodium_mg, null, `${where}: sodium_mg`);
              assertEquals(out.sodium_low_mg, null, `${where}: sodium_low_mg`);
              assertEquals(out.sodium_high_mg, null, `${where}: sodium_high_mg`);
            }
          }
        }
      }
    }
  });

  it('T_REF == TIER_MEAL_MIN (both 120) — asserted behaviourally', () => {
    // Hydration invariant 10 / carbs invariant 10. The two constants are equal
    // for UNRELATED reasons and are pinned by assertion, never derived one from
    // the other. Observed through behaviour so neither constant needs exporting.
    const grid = [
      0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225,
      240,
    ];
    const tRefObserved = grid.find((t) =>
      calculatePreWorkoutHydration({
        bodyWeightKg: 65,
        workoutDurationMin: 90,
        timeBeforeWorkoutMin: t,
        tempC: 22,
      }).regime === 'cited'
    );
    const mealMinObserved = grid.find((t) =>
      calculatePreWorkoutCarbs({
        bodyWeightKg: 65,
        timeBeforeWorkoutMin: t,
        workoutDurationMin: 90,
      }).tiers.some((x) => x.tier === 'meal')
    );
    assertEquals(tRefObserved, 120, 'hydration T_REF drifted off 120');
    assertEquals(
      mealMinObserved,
      120,
      `carbs TIER_MEAL_MIN (${mealMinObserved}) diverged from hydration T_REF ` +
        `(${tRefObserved}). Pinned equal by assertion, NOT shared code — if one ` +
        `moved deliberately, move this pin deliberately too.`,
    );
  });

  it('the two carb bands are deliberately different objects', () => {
    // The payload's plan band is Thomas's [1*BW, 4*BW]; the solver's is
    // carbs_g * (1 -/+ 0.125). Conflating them lets a 65 kg athlete's 195 g
    // plan accept 260 g of food. Pin that they do NOT coincide in the cited
    // regime, and that the per-tier windows carry the SOLVER tolerance.
    const out = calculatePreWorkoutCarbs({
      bodyWeightKg: 65,
      timeBeforeWorkoutMin: 180,
      workoutDurationMin: 90,
    });
    assertEquals(out.carbs_g, 195);
    assertEquals(out.carbs_low_g, 65); // 1 * BW — plan band
    assertEquals(out.carbs_high_g, 260); // 4 * BW — plan band
    const tierSumLow = out.tiers.reduce((a, t) => a + t.range_low_g, 0);
    const tierSumHigh = out.tiers.reduce((a, t) => a + t.range_high_g, 0);
    assertAlmostEquals(tierSumLow, 195 * 0.875, TOL); // 170.625, not 65
    assertAlmostEquals(tierSumHigh, 195 * 1.125, TOL); // 219.375, not 260
  });
});
