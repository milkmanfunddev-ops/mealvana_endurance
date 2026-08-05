/**
 * Pre-workout hydration — behaviour tests for SSOT v6 (+ sodium v3).
 *
 * Normative source: docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md §1 and §3, and the
 * specs it digests (`spec/fueling/pre-workout-{hydration,sodium}.md`).
 *
 * SCOPE. The ratified NUMBERS are pinned by the golden vectors in
 * `pre-workout-vectors.test.ts`, which both this engine and the Dart engine run.
 * This file covers what a vector table cannot: boundary behaviour either side of
 * a threshold, the three deliberate discontinuities at t = 120, monotonicity,
 * purity with respect to `hydrationCheck`, and the shape of the gate path.
 *
 * The v1 suite that lived here (6 ml/kg, a 5–7 ml/kg band, a flat 250 ml tier 2,
 * 450/150/0 mg sodium and an integer `tier`) was DELETED rather than adapted —
 * every one of those numbers is now wrong, and `tier` no longer exists.
 *
 * Run with:
 *   deno test supabase/functions/generate-macros-v4/pre-workout-new.test.ts
 */

import {
  assert,
  assertAlmostEquals,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import {
  calculatePreWorkoutHydration,
  type HydrationCheck,
} from './pre-workout.ts';

const TOL = 1e-3;

/** Spec constants, restated here on purpose. If this file imported the
 * engine's own constants a wrong constant would agree with itself. */
const T_REF = 120;
const TOPUP_ML_KG = 4.0;
const PLAN_CAP_ML_KG = 12.0;
const R_CEILING = 400.0;
const K = 3.2 / 60; // MUST be computed, never the literal 0.0533333

/** Non-gated call: 90 min at 22 °C never trips `dur < 60 AND temp < 30`. */
function calc(
  bw: number,
  t: number,
  opts: {
    check?: HydrationCheck;
    durationMin?: number;
    tempC?: number | null;
  } = {},
) {
  return calculatePreWorkoutHydration({
    bodyWeightKg: bw,
    workoutDurationMin: opts.durationMin ?? 90,
    timeBeforeWorkoutMin: t,
    tempC: opts.tempC === undefined ? 22 : opts.tempC,
    hydrationCheck: opts.check ?? 'unknown',
  });
}

/** The spec's taper, restated: f(x) = A0 + (7.5·BW − A0)·min(x, T_REF)/T_REF. */
function f(bw: number, x: number): number {
  const a0 = Math.min(250, 7.5 * bw);
  return a0 + (7.5 * bw - a0) * Math.min(x, T_REF) / T_REF;
}

// ============================================================================
// The gate — the only short-circuit
// ============================================================================

describe('Gate: workoutDurationMin < 60 AND tempC < 30', () => {
  it('45 min at 22 °C gates — and returns null, never 0', () => {
    const r = calc(70, 180, { durationMin: 45 });
    assert(r.gate_triggered, 'gate should trigger');
    // null and 0 are different answers. `0` would mean "drink nothing"; null
    // means Mealvana makes no statement. A test that passes on 0 is broken.
    assertEquals(r.fluid_ml, null, 'fluid_ml must be null, not 0');
    assertEquals(r.fluid_low_ml, null);
    assertEquals(r.fluid_high_ml, null);
    assertEquals(r.tiers.length, 0, 'gate path emits an EMPTY tiers array');
    assertEquals(r.regime, 'gated');
    assertEquals(r.target_basis, 'none');
    assertEquals(r.hydration_check_used, null);
    assert(
      r.message?.includes('No structured pre-hydration needed'),
      'gate copy present',
    );
  });

  it('the gate is AND-joined: 45 min at 31 °C does NOT gate', () => {
    const r = calc(70, 180, { durationMin: 45, tempC: 31 });
    assert(!r.gate_triggered);
    assert(r.fluid_ml !== null && r.fluid_ml > 0);
  });

  it('both thresholds are strict `<` — dur == 60 and temp == 30 do NOT gate', () => {
    assertEquals(calc(70, 180, { durationMin: 60, tempC: 22 }).gate_triggered, false);
    assertEquals(calc(70, 180, { durationMin: 45, tempC: 30 }).gate_triggered, false);
    // ...and one tick under each still gates.
    assertEquals(calc(70, 180, { durationMin: 59, tempC: 29.999 }).gate_triggered, true);
  });

  it('tempC null defaults to 22 — the default is applied BEFORE the gate', () => {
    assertEquals(calc(70, 180, { durationMin: 45, tempC: null }).gate_triggered, true);
    assertEquals(calc(70, 180, { durationMin: 90, tempC: null }).gate_triggered, false);
  });

  it('the gate ignores lead time entirely — even t = 240 gates', () => {
    for (const t of [0, 30, 119, 120, 240]) {
      assertEquals(
        calc(65, t, { durationMin: 45 }).gate_triggered,
        true,
        `t=${t} must still gate`,
      );
    }
  });
});

// ============================================================================
// Regime + target_basis — what replaced the integer tier
// ============================================================================

describe('Regime and target_basis (the integer `tier` is retired)', () => {
  it('the retired integer `tier` field is gone from the result', () => {
    const r = calc(70, 180) as unknown as Record<string, unknown>;
    assert(
      !('tier' in r),
      'PW-013 retired the integer tier; regime/target_basis replace it',
    );
  });

  it('t >= 120 is `cited` / `evidenced_band`', () => {
    for (const t of [120, 135, 180, 240]) {
      const r = calc(65, t);
      assertEquals(r.regime, 'cited', `t=${t}`);
      assertEquals(r.target_basis, 'evidenced_band', `t=${t}`);
    }
  });

  it('120 is inclusive at the bottom — 119.999 is already `extrapolated`', () => {
    assertEquals(calc(65, 120).regime, 'cited');
    assertEquals(calc(65, 119.999).regime, 'extrapolated');
    assertEquals(calc(65, 119.999).target_basis, 'design_choice');
  });

  it('below 120 everything is a design choice, never evidenced', () => {
    for (const t of [0, 5, 15, 29.999, 30, 45, 60, 90, 105, 119]) {
      assertEquals(calc(65, t).target_basis, 'design_choice', `t=${t}`);
      assert(
        ['extrapolated', 'clearance_bound'].includes(calc(65, t).regime),
        `t=${t}: regime`,
      );
    }
  });

  it('`clearance_bound` fires only where 400·e^(K·t) < 10·BW', () => {
    // For 65 kg the crossover is ln(650/400)/K ≈ 9.10 min — inside the top-off
    // tier, which is invariant 9's whole claim.
    const crossover = Math.log(10 * 65 / R_CEILING) / K;
    assert(crossover < 30, `crossover ${crossover} must sit inside the top-off tier`);
    assertEquals(calc(65, 0).regime, 'clearance_bound');
    assertEquals(calc(65, crossover - 0.01).regime, 'clearance_bound');
    assertEquals(calc(65, crossover + 0.01).regime, 'extrapolated');
    assertEquals(calc(65, 30).regime, 'extrapolated');
  });
});

// ============================================================================
// Tier membership and the no-split rule
// ============================================================================

describe('Fluid tiers — furthest-out first, and fluid NEVER splits', () => {
  it('t >= 120 emits [meal, snack, top_off] with all fluid in `meal` on pale', () => {
    const r = calc(65, 180, { check: 'pale' });
    assertEquals(r.tiers.map((x) => x.tier), ['meal', 'snack', 'top_off']);
    assertAlmostEquals(r.tiers[0].fluid_ml, 7.5 * 65, TOL);
    assertEquals(r.tiers[1].fluid_ml, 0, 'pale adds no snack top-up');
    assertEquals(r.tiers[2].fluid_ml, 0);
  });

  it('dark puts exactly 4 ml/kg — and only that — in the snack tier', () => {
    const r = calc(65, 180, { check: 'dark' });
    assertAlmostEquals(r.tiers[0].fluid_ml, 7.5 * 65, TOL);
    assertAlmostEquals(r.tiers[1].fluid_ml, TOPUP_ML_KG * 65, TOL);
    assertEquals(r.tiers[2].fluid_ml, 0);
  });

  it('30 <= t < 120 emits [snack, top_off], all of it in `snack`', () => {
    const r = calc(65, 90);
    assertEquals(r.tiers.map((x) => x.tier), ['snack', 'top_off']);
    assertAlmostEquals(r.tiers[0].fluid_ml, f(65, 90), TOL);
    assertEquals(r.tiers[1].fluid_ml, 0);
  });

  it('t < 30 emits [top_off] only', () => {
    const r = calc(65, 15);
    assertEquals(r.tiers.map((x) => x.tier), ['top_off']);
    assertAlmostEquals(r.tiers[0].fluid_ml, f(65, 15), TOL);
  });

  it('30 is inclusive at the bottom — 29.999 is already top-off only', () => {
    assertEquals(calc(65, 30).tiers.map((x) => x.tier), ['snack', 'top_off']);
    assertEquals(calc(65, 29.999).tiers.map((x) => x.tier), ['top_off']);
  });

  it('inv 2 — fluid_ml == sum(tiers[].fluid_ml) across the whole grid', () => {
    for (const bw of [30, 50, 65, 90, 120]) {
      for (const t of [0, 15, 30, 45, 60, 90, 105, 119, 120, 180, 240]) {
        for (const check of ['pale', 'dark', 'unknown'] as HydrationCheck[]) {
          const r = calc(bw, t, { check });
          const sum = r.tiers.reduce((a, x) => a + x.fluid_ml, 0);
          assertAlmostEquals(
            sum,
            r.fluid_ml as number,
            TOL,
            `BW=${bw} t=${t} check=${check}`,
          );
        }
      }
    }
  });
});

// ============================================================================
// hydrationCheck — the only individualization in the slice
// ============================================================================

describe('hydrationCheck', () => {
  it('defaults to `unknown` when omitted', () => {
    const explicit = calculatePreWorkoutHydration({
      bodyWeightKg: 65,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 90,
      tempC: 22,
      hydrationCheck: 'unknown',
    });
    const omitted = calculatePreWorkoutHydration({
      bodyWeightKg: 65,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 90,
      tempC: 22,
    });
    assertEquals(omitted.fluid_ml, explicit.fluid_ml);
    assertEquals(omitted.hydration_check_used, 'unknown');
  });

  it('above T_REF: dark adds exactly 4 ml/kg to the TARGET', () => {
    for (const bw of [40, 65, 90]) {
      const pale = calc(bw, 180, { check: 'pale' }).fluid_ml as number;
      const dark = calc(bw, 180, { check: 'dark' }).fluid_ml as number;
      assertAlmostEquals(dark - pale, TOPUP_ML_KG * bw, TOL, `BW=${bw}`);
    }
  });

  it('inv 8b — the BAND never moves with the check, on either side of T_REF', () => {
    for (const t of [0, 15, 30, 90, 119, 120, 180, 240]) {
      const pale = calc(65, t, { check: 'pale' });
      for (const check of ['dark', 'unknown'] as HydrationCheck[]) {
        const o = calc(65, t, { check });
        assertEquals(o.fluid_low_ml, pale.fluid_low_ml, `t=${t} low`);
        assertEquals(o.fluid_high_ml, pale.fluid_high_ml, `t=${t} high`);
        assertEquals(o.regime, pale.regime, `t=${t} regime`);
        assertEquals(o.target_basis, pale.target_basis, `t=${t} basis`);
      }
    }
  });

  it('below T_REF the check changes NOTHING — not even the target', () => {
    for (const t of [0, 15, 30, 60, 90, 119]) {
      const pale = calc(65, t, { check: 'pale' });
      for (const check of ['dark', 'unknown'] as HydrationCheck[]) {
        assertEquals(calc(65, t, { check }).fluid_ml, pale.fluid_ml, `t=${t}`);
      }
    }
  });

  it('the echo normalises `unknown` -> `pale` ONLY above T_REF', () => {
    // Normalising at the top of the function instead fails four vectors.
    assertEquals(calc(65, 120, { check: 'unknown' }).hydration_check_used, 'pale');
    assertEquals(calc(65, 240, { check: 'unknown' }).hydration_check_used, 'pale');
    assertEquals(calc(65, 119, { check: 'unknown' }).hydration_check_used, 'unknown');
    assertEquals(calc(65, 0, { check: 'unknown' }).hydration_check_used, 'unknown');
    // pale/dark are echoed raw on both sides.
    for (const t of [0, 119, 120, 240]) {
      assertEquals(calc(65, t, { check: 'pale' }).hydration_check_used, 'pale');
      assertEquals(calc(65, t, { check: 'dark' }).hydration_check_used, 'dark');
    }
  });
});

// ============================================================================
// The three deliberate discontinuities at t = 120 — pinned, never smoothed
// ============================================================================

describe('Discontinuities at T_REF (deliberate — do not smooth)', () => {
  const eps = 1e-5;

  it('fluid_low_ml steps 0 -> 5·BW', () => {
    assertEquals(calc(65, T_REF - eps).fluid_low_ml, 0);
    assertAlmostEquals(calc(65, T_REF + eps).fluid_low_ml as number, 5 * 65, TOL);
  });

  it('fluid_high_ml steps min(10·BW, clearance) -> 12·BW on EVERY path', () => {
    for (const check of ['pale', 'dark', 'unknown'] as HydrationCheck[]) {
      assertAlmostEquals(
        calc(65, T_REF - eps, { check }).fluid_high_ml as number,
        10 * 65,
        TOL,
        `check=${check}`,
      );
      assertAlmostEquals(
        calc(65, T_REF + eps, { check }).fluid_high_ml as number,
        PLAN_CAP_ML_KG * 65,
        TOL,
        `check=${check}`,
      );
    }
  });

  it('on the dark path only, fluid_ml steps by exactly 4·BW', () => {
    for (const bw of [40, 65, 90]) {
      const below = calc(bw, T_REF - eps, { check: 'dark' }).fluid_ml as number;
      const above = calc(bw, T_REF + eps, { check: 'dark' }).fluid_ml as number;
      assertAlmostEquals(above - below, TOPUP_ML_KG * bw, 1e-3 * bw, `BW=${bw}`);
    }
  });

  it('the PALE path is continuous at both 120 and 30', () => {
    for (const bw of [40, 65, 90]) {
      for (const b of [T_REF, 30]) {
        const below = calc(bw, b - eps, { check: 'pale' }).fluid_ml as number;
        const above = calc(bw, b + eps, { check: 'pale' }).fluid_ml as number;
        assert(
          Math.abs(above - below) < 1e-3 * bw,
          `BW=${bw}: pale path is discontinuous at t=${b} (${below} -> ${above})`,
        );
      }
    }
  });

  it('the odd consequence is INTENDED: dark at t-121 exceeds the max at t-119', () => {
    // 747.5 > 650 for a 65 kg athlete. The first plan spans two windows with a
    // clearing gap; the second is 90 minutes with none. Do not "fix" this.
    const dark121 = calc(65, 121, { check: 'dark' }).fluid_ml as number;
    const high119 = calc(65, 119).fluid_high_ml as number;
    assert(dark121 > high119, `${dark121} must exceed ${high119}`);
  });
});

// ============================================================================
// Shape invariants over the grid
// ============================================================================

describe('Invariants over the 15-minute grid', () => {
  const GRID = [
    0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240,
  ];
  const WEIGHTS = [30, 45, 65, 90, 120, 160];

  it('inv 1 — 0 <= low <= plan <= high everywhere off the gate path', () => {
    for (const bw of WEIGHTS) {
      for (const t of GRID) {
        for (const check of ['pale', 'dark', 'unknown'] as HydrationCheck[]) {
          const r = calc(bw, t, { check });
          const where = `BW=${bw} t=${t} check=${check}`;
          assert(!r.gate_triggered, `${where}: 90 min @ 22 °C must not gate`);
          const low = r.fluid_low_ml as number;
          const plan = r.fluid_ml as number;
          const high = r.fluid_high_ml as number;
          assert(low >= 0, `${where}: low ${low} < 0`);
          assert(low <= plan + 1e-9, `${where}: low ${low} > plan ${plan}`);
          assert(plan <= high + 1e-9, `${where}: plan ${plan} > high ${high}`);
        }
      }
    }
  });

  it('inv 3 — fluid_ml is non-decreasing in t on both the pale and dark paths', () => {
    for (const bw of WEIGHTS) {
      for (const check of ['pale', 'dark'] as HydrationCheck[]) {
        let prev = -Infinity;
        for (const t of GRID) {
          const cur = calc(bw, t, { check }).fluid_ml as number;
          assert(
            cur >= prev - 1e-9,
            `BW=${bw} check=${check}: fluid dropped ${prev} -> ${cur} at t=${t}`,
          );
          prev = cur;
        }
      }
    }
  });

  it('inv 8a — the 12 ml/kg plan cap has teeth on every path', () => {
    for (const bw of WEIGHTS) {
      for (const t of GRID) {
        for (const check of ['pale', 'dark', 'unknown'] as HydrationCheck[]) {
          const r = calc(bw, t, { check });
          assert(
            (r.fluid_ml as number) <= PLAN_CAP_ML_KG * bw + 1e-9,
            `BW=${bw} t=${t} check=${check}: plan exceeds PLAN_CAP. Raising ` +
              `TOPUP_ML_KG past 4.5 must fail HERE, not silently exceed ACSM 2007.`,
          );
        }
        if (t >= T_REF) {
          // min(7.5 + 5, 12)·BW must select the CAP, not the sum.
          const darkHigh = calc(bw, t, { check: 'dark' }).fluid_high_ml as number;
          assertAlmostEquals(darkHigh, PLAN_CAP_ML_KG * bw, TOL, `BW=${bw} t=${t}`);
          assert(
            darkHigh < 12.5 * bw - 1e-9,
            `BW=${bw} t=${t}: the cap did not bind — high equals the uncapped sum`,
          );
        }
      }
    }
  });

  it('above T_REF the output is time-INDEPENDENT (120 == 180 == 240)', () => {
    for (const check of ['pale', 'dark'] as HydrationCheck[]) {
      const at120 = calc(65, 120, { check });
      for (const t of [135, 180, 240]) {
        assertEquals(calc(65, t, { check }).fluid_ml, at120.fluid_ml, `t=${t}`);
      }
    }
  });

  it('t > 240 returns the same as t = 240 (the taper is clamped at T_REF)', () => {
    assertEquals(calc(65, 480).fluid_ml, calc(65, 240).fluid_ml);
  });

  it('negative lead time is clamped to 0, not rejected', () => {
    const r = calc(65, -15);
    assertAlmostEquals(r.fluid_ml as number, 250, TOL, 'clamps to the t=0 anchor');
    assertEquals(r.regime, 'clearance_bound');
    assertEquals(r.tiers.map((x) => x.tier), ['top_off']);
  });

  it('the A0 guard binds only below 33.3 kg', () => {
    // A0 = min(250, 7.5·BW). At 30 kg the guard makes the taper degenerate:
    // 7.5·30 = 225 < 250, so f(x) is flat at 225 and t = 0 already gives 225.
    assertAlmostEquals(calc(30, 0).fluid_ml as number, 225, TOL);
    assertAlmostEquals(calc(30, 180).fluid_ml as number, 225, TOL);
    // At 34 kg it does not bind — the taper is a genuine ramp.
    assert((calc(34, 180).fluid_ml as number) > (calc(34, 0).fluid_ml as number));
  });
});

// ============================================================================
// Sodium v3 — Mealvana sets NO pre-workout sodium target
// ============================================================================

describe('Sodium v3 — always null, never 0', () => {
  it('all three sodium fields are null on every path', () => {
    const cases = [
      calc(65, 180, { check: 'pale' }),
      calc(65, 180, { check: 'dark' }),
      calc(65, 90),
      calc(65, 15),
      calc(65, 0),
      calc(65, 180, { durationMin: 45 }), // gate path
      calc(120, 240, { tempC: 40 }),
      calc(30, 60, { tempC: null }),
    ];
    for (const r of cases) {
      // Strict null: `assertEquals(x, 0)` would pass on a 0 and that is exactly
      // the regression this guards. 0 says "consume no sodium"; null says
      // "we set no target".
      assertEquals(r.sodium_mg, null);
      assertEquals(r.sodium_low_mg, null);
      assertEquals(r.sodium_high_mg, null);
    }
  });

  it('the v1 constants are gone — 450 / 300 / 600 / 150 appear nowhere', () => {
    const r = calc(65, 180);
    const values = [r.sodium_mg, r.sodium_low_mg, r.sodium_high_mg];
    for (const bad of [0, 450, 300, 600, 150, 100, 200]) {
      assert(
        !values.includes(bad as unknown as null),
        `sodium regressed to the v1 value ${bad}`,
      );
    }
  });
});
