/**
 * Regression tests for #25: Pass 1 (food selection) scoring no longer
 * treats sodium gap-closing as an objective. Sodium delivery is the job
 * of Pass 2 (pickDrink) and Pass 3 (pickElectrolyte).
 *
 * The bug: in the old scoring, a high-sodium candidate (e.g. Potato + Salt
 * at ~600 mg) was preferred over a low-sodium candidate (e.g. Oatmeal at
 * ~10 mg) when both had similar carb fit, because the high-sodium pick
 * "closed" the session-wide sodium gap. That meal-phase choice then
 * starved Pass 2/3 of headroom and cascaded into the no-water bug (#22).
 *
 * After the fix: sodiumErr / fluidErr (and the symmetric under-cap penalties)
 * are removed from baseScore. Only sodium/fluid OverPenalties remain — and
 * those only fire in the safePool-fallback path.
 *
 * Run with:
 *   deno test --no-check --allow-env --allow-net \
 *     supabase/functions/generate-macros-v4/pre-workout-sodium-scoring.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { pickBestFormula } from './pre-workout-scoring.ts';
import type { PlanState, ScoredFormula, PreWorkoutTemplate } from './types.ts';

// ============================================================================
// Fixtures
// ============================================================================

function makeTemplate(overrides: Partial<PreWorkoutTemplate> & { id: string; name: string }): PreWorkoutTemplate {
  return {
    base_category: 'grain',
    time_window: '1.5-3 hours',
    digestion_speed: 'medium',
    allergens: [],
    serving_unit: 'serving',
    min_servings: 1,
    max_servings: 4,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: 30,
    protein_per_serving: 5,
    fat_per_serving: 3,
    sodium_mg: 0,
    fluid_ml: 0,
    template_type: 'food',
    is_active: true,
    component_food_names: [],
    component_quantities: {},
    ...overrides,
  };
}

function makeState(): PlanState {
  // Session-wide pre-workout targets for a typical mid-distance athlete.
  return {
    used_foods: new Set(),
    sports_drink_used: false,
    used_categories: new Set(),
    carbs_delivered: 0,
    protein_delivered: 0,
    sodium_delivered: 0,
    fluid_delivered: 0,
    carbs_target: 60,
    carbs_low: 50,
    carbs_high: 80,
    protein_target: 10,
    protein_low: 5,
    protein_high: 20,
    sodium_target: 450,
    sodium_low: 300,
    sodium_high: 600,
    fluid_target: 300,
    fluid_low: 200,
    fluid_high: 500,
  };
}

/**
 * Build a ScoredFormula by hand — bypasses scoreFormula so we can hold
 * carb fit identical between the two candidates and isolate the effect
 * of sodium content on selection.
 */
function makeScored(
  template: PreWorkoutTemplate,
  servings: number,
  carbs: number,
  protein: number,
  sodium: number,
  fluid: number,
  gap: number,
): ScoredFormula {
  return { template, servings, carbs, protein, sodium, fluid, gap, addOns: [] };
}

// ============================================================================
// The #25 regression: high-sodium candidate must not dominate
// ============================================================================

Deno.test('Pass 1 does NOT prefer high-sodium candidate when carb fit is identical (#25)', () => {
  // Two candidates with IDENTICAL carb / protein delivery (both close the carb
  // gap perfectly), differing only in sodium content. Before #25 fix, the
  // high-sodium one would win consistently because it closed the 450 mg
  // session sodium gap. After the fix, scoring must be sodium-blind for Pass 1.
  //
  // Verification strategy: under the #33 fix `pickBestFormula` is deterministic
  // (lexicographic id tie-break, no randomness), so we can no longer assert
  // "both win sometimes" via random trials. Instead we swap which candidate
  // carries the high sodium — if sodiumErr were still part of the score, the
  // winner would change. Sodium-blind scoring keeps the winner stable.
  const potatoSaltHigh = makeScored(
    makeTemplate({ id: 'potato-salt', name: 'Potato + Salt', sodium_mg: 300 }),
    2, 60, 10, 600, 0, 0,
  );
  const oatmealLow = makeScored(
    makeTemplate({ id: 'oatmeal', name: 'Oatmeal' }),
    2, 60, 10, 10, 0, 0,
  );
  const winnerHighOnPotato = pickBestFormula([potatoSaltHigh, oatmealLow], makeState(), 60);

  const potatoSaltLow = makeScored(
    makeTemplate({ id: 'potato-salt', name: 'Potato + Salt', sodium_mg: 5 }),
    2, 60, 10, 10, 0, 0,
  );
  const oatmealHigh = makeScored(
    makeTemplate({ id: 'oatmeal', name: 'Oatmeal' }),
    2, 60, 10, 600, 0, 0,
  );
  const winnerHighOnOatmeal = pickBestFormula([potatoSaltLow, oatmealHigh], makeState(), 60);

  assertEquals(
    winnerHighOnPotato.template.id,
    winnerHighOnOatmeal.template.id,
    `Winner changed when sodium was swapped between candidates — sodiumErr is still ` +
    `influencing Pass 1 scoring (got '${winnerHighOnPotato.template.id}' with high-sodium ` +
    `potato, '${winnerHighOnOatmeal.template.id}' with high-sodium oatmeal)`,
  );
});

Deno.test('Pass 1 does NOT prefer high-fluid candidate when carb fit is identical (#25, fluid symmetry)', () => {
  // Same shape as the sodium variant: swap which candidate carries the
  // high-fluid value. Under the fix the winner must stay stable (fluid-blind
  // scoring). Pre-#33 this used random trials; that no longer applies under
  // deterministic tie-break.
  //
  // Both fluid values stay at or below `fluid_high = 500` so the intentional
  // `fluidOverPenalty` (a safety guard for the fallback path, kept by design)
  // doesn't fire and confound the assertion — we are only testing for residual
  // fluidErr / fluid-gap-closing terms in Pass 1 baseScore.
  const sdHeavyHighFluid = makeScored(
    makeTemplate({ id: 'sd-heavy', name: 'Sports Drink Heavy', fluid_ml: 250 }),
    2, 60, 10, 0, 500, 0,
  );
  const drySnackLowFluid = makeScored(
    makeTemplate({ id: 'dry-snack', name: 'Dry Snack' }),
    2, 60, 10, 0, 0, 0,
  );
  const winnerHighOnSd = pickBestFormula([sdHeavyHighFluid, drySnackLowFluid], makeState(), 60);

  const sdHeavyLowFluid = makeScored(
    makeTemplate({ id: 'sd-heavy', name: 'Sports Drink Heavy', fluid_ml: 0 }),
    2, 60, 10, 0, 0, 0,
  );
  const drySnackHighFluid = makeScored(
    makeTemplate({ id: 'dry-snack', name: 'Dry Snack' }),
    2, 60, 10, 0, 500, 0,
  );
  const winnerHighOnDry = pickBestFormula([sdHeavyLowFluid, drySnackHighFluid], makeState(), 60);

  assertEquals(
    winnerHighOnSd.template.id,
    winnerHighOnDry.template.id,
    `Winner changed when fluid was swapped between candidates — fluidErr is still ` +
    `influencing Pass 1 scoring`,
  );
});

// ============================================================================
// Carb fit IS still the dominant objective (sanity / no-regression)
// ============================================================================

Deno.test('Pass 1 still prefers better carb fit over worse, regardless of sodium', () => {
  // Perfect-carb low-sodium candidate vs. way-off-carb high-sodium candidate.
  // The carb-fit winner must dominate — otherwise we've gone too far in
  // stripping objectives.
  const perfectCarbLowSodium = makeScored(
    makeTemplate({ id: 'oatmeal', name: 'Oatmeal' }),
    2, 60, 10, 10, 0,
    0,  // perfect carb gap
  );
  const wayOffCarbHighSodium = makeScored(
    makeTemplate({ id: 'salty-snack', name: 'Salty Snack', sodium_mg: 225 }),
    2, 10, 5, 450, 0,
    50,  // huge carb gap — completely misses the 60g target
  );

  let perfectWins = 0;
  const trials = 50;
  for (let i = 0; i < trials; i++) {
    const winner = pickBestFormula([perfectCarbLowSodium, wayOffCarbHighSodium], makeState(), 60);
    if (winner.template.id === 'oatmeal') perfectWins++;
  }

  // The carb-fit winner should win essentially all the time — a 50g carb
  // miss dwarfs anything sodium-related can do under the new scoring.
  assert(
    perfectWins >= 45,
    `expected carb-fit winner to dominate (got ${perfectWins}/${trials})`,
  );
});

// ============================================================================
// Over-cap penalty is still active in fallback path (kept by design)
// ============================================================================

Deno.test('sodiumOverPenalty still fires in fallback when safePool is empty', () => {
  // Construct a scenario where every candidate exceeds sodium_high — forcing
  // the safePool-empty fallback. The least-over candidate should still win
  // because sodiumOverPenalty remains active as a tiebreaker.
  const state = makeState();
  state.sodium_delivered = 500; // headroom = 100 mg before hitting sodium_high=600

  const slightlyOver = makeScored(
    makeTemplate({ id: 'slight-over', name: 'Slightly Over' }),
    2, 60, 10, 150, 0,  // 500 + 150 = 650 → over high by 50
    0,
  );
  const wayOver = makeScored(
    makeTemplate({ id: 'way-over', name: 'Way Over' }),
    2, 60, 10, 400, 0,  // 500 + 400 = 900 → over high by 300
    0,
  );

  let slightWins = 0;
  const trials = 50;
  for (let i = 0; i < trials; i++) {
    // Need fresh state each call so sodium_delivered doesn't accumulate
    const s = makeState();
    s.sodium_delivered = 500;
    const winner = pickBestFormula([slightlyOver, wayOver], s, 60);
    if (winner.template.id === 'slight-over') slightWins++;
  }

  // The least-over candidate must dominate — proves sodiumOverPenalty is
  // still doing its tiebreaker job in the fallback path.
  assert(
    slightWins >= 45,
    `expected least-over candidate to dominate in fallback (got ${slightWins}/${trials})`,
  );
});
