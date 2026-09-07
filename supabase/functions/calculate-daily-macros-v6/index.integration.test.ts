/**
 * Integration tests for the calculate-daily-macros-v6 Edge Function (the live engine; calculate-daily-macros is the frozen v5)
 *
 * Calls the deployed edge function via HTTP to verify end-to-end behavior.
 * Mirrors the unit/pipeline tests in index.test.ts but exercises the full
 * HTTP stack: CORS, JSON parsing, validation, calculation, and response.
 *
 * Run with:
 *   export SUPABASE_URL=https://vlmtsdzpnjnavdgytcmi.supabase.co
 *   export SUPABASE_ANON_KEY=<dev-anon-key>
 *   deno test --allow-net --allow-env supabase/functions/calculate-daily-macros-v6/index.integration.test.ts
 *
 * When SUPABASE_URL / SUPABASE_ANON_KEY are not set the tests are skipped
 * (ignored), so the file stays green in offline unit-test runs.
 */

import {
  assertEquals,
  assert,
} from 'https://deno.land/std@0.224.0/assert/mod.ts';

// ============================================================================
// Configuration
// ============================================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || '';
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/calculate-daily-macros-v6`;
const HAS_ENV = SUPABASE_URL.length > 0 && SUPABASE_ANON_KEY.length > 0;

/** Deployed-function test — skipped when the Supabase env is not configured. */
function integrationTest(name: string, fn: () => Promise<void>) {
  Deno.test({ name, ignore: !HAS_ENV, fn });
}

// ============================================================================
// Helpers
// ============================================================================

async function callEdgeFunction(
  body: Record<string, unknown>,
): Promise<{ status: number; data: Record<string, unknown> }> {
  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  return { status: response.status, data };
}

function assertWithinPercent(
  actual: number,
  expected: number,
  percent: number,
  message?: string,
) {
  const tolerance = Math.abs(expected) * (percent / 100);
  const diff = Math.abs(actual - expected);
  if (diff > tolerance) {
    throw new Error(
      `${message || 'Assertion failed'}: expected ${expected} ±${percent}%, got ${actual} (diff: ${diff.toFixed(2)}, tolerance: ${tolerance.toFixed(2)})`,
    );
  }
}

/** Reference athlete input with overrides */
function refInput(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    sex: 'male',
    age: 34,
    weight_kg: 75,
    height_cm: 178,
    body_fat_pct: 14.7,
    lifestyle: 'desk',
    typical_weekly_hours: 10,
    carb_cycle_opt_in: false,
    training_phase: 'base',
    sessions: [],
    yesterday_tss: null,
    yesterday_hours_since: null,
    tomorrow_tss: null,
    tomorrow_duration_hr: null,
    tomorrow_is_race: false,
    weekly_hours_ratio: 1.0,
    mode: 'prospective',
    ...overrides,
  };
}

function session(
  sport: string,
  duration_hr: number,
  pct_conversational: number,
  pct_tempo: number,
  pct_allout: number,
  tss?: number | null,
) {
  return { sport, duration_hr, pct_conversational, pct_tempo, pct_allout, tss: tss ?? null };
}

// ============================================================================
// Preflight check
// ============================================================================

integrationTest('Integration: Edge function is reachable', async () => {
  assert(SUPABASE_URL.length > 0, 'SUPABASE_URL must be set');
  assert(SUPABASE_ANON_KEY.length > 0, 'SUPABASE_ANON_KEY must be set');

  const { status } = await callEdgeFunction(refInput());
  assertEquals(status, 200);
});

// ============================================================================
// Validation (HTTP layer)
// ============================================================================

integrationTest('Integration: Rejects GET method', async () => {
  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
  });
  assertEquals(response.status, 405);
  await response.json(); // consume body
});

integrationTest('Integration: Rejects invalid JSON', async () => {
  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: 'not json',
  });
  assertEquals(response.status, 400);
  const data = await response.json();
  assert(data.error?.includes('Invalid JSON') || data.error?.includes('invalid'), `Expected JSON error, got: ${data.error}`);
});

integrationTest('Integration: Returns validation error for missing sex', async () => {
  const { status, data } = await callEdgeFunction({ weight_kg: 75, height_cm: 178, age: 34, sessions: [] });
  assertEquals(status, 400);
  assert(typeof data.error === 'string');
});

integrationTest('Integration: Returns validation error for bad zones', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.0, 0.70, 0.20, 0.20)], // sums to 1.1
  }));
  assertEquals(status, 400);
  assert((data.error as string).includes('sum to 1.0'));
});

integrationTest('Integration: Returns validation error for invalid sport', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('hiking', 1.0, 0.70, 0.20, 0.10)],
  }));
  assertEquals(status, 400);
  assert(typeof data.error === 'string');
});

// ============================================================================
// Iteration 1: Baseline + Session
// ============================================================================

integrationTest('Integration Iter1: Rest day (no sessions)', async () => {
  const { status, data } = await callEdgeFunction(refInput());
  assertEquals(status, 200);

  // Fat capped at 30 %E (83g); excess kcal rerouted to carb → 322g.
  assertWithinPercent(data.carb_g as number, 322, 2);
  assertWithinPercent(data.prot_g as number, 115, 5);
  assertWithinPercent(data.fat_g as number, 83, 5);
  assertWithinPercent(data.tdee as number, 2501, 5);
  assertEquals(data.session_kcal, 0);
  assertEquals(data.mode, 'prospective');
  assertEquals(data.algorithm_version, 'v6.0.0');
});

integrationTest('Integration Iter1: 90-min run', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  }));
  assertEquals(status, 200);

  // Zones 0.70/0.20/0.10 → IF ≈ 0.771; step 10b redistribution → carb 569
  assertWithinPercent(data.carb_g as number, 569, 2);
  assertWithinPercent(data.prot_g as number, 130, 5);
  assertWithinPercent(data.fat_g as number, 133, 5);
  assertWithinPercent(data.session_kcal as number, 1309, 5);
  assert((data.ea as number) > 30, 'EA should be above 30 for normal training');
});

integrationTest('Integration Iter1: 4hr bike ride', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('cycling', 4.0, 0.60, 0.30, 0.10)],
  }));
  assertEquals(status, 200);

  // Zones 0.60/0.30/0.10 → IF ≈ 0.791; carb pushed to the 12 g/kg clamp
  assertWithinPercent(data.carb_g as number, 899, 2);
  assertWithinPercent(data.prot_g as number, 130, 5);
  assertWithinPercent(data.session_kcal as number, 3007, 5);
});

integrationTest('Integration Iter1: Strength session', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('strength', 1.0, 0.70, 0.20, 0.10)],
  }));
  assertEquals(status, 200);

  // Flat 27 g/hr strength carb demand (Q-003): 300 + 27 = 327 pre-cap → 382
  assertWithinPercent(data.carb_g as number, 382, 2);
  assertWithinPercent(data.prot_g as number, 138, 5);
  assertWithinPercent(data.session_kcal as number, 386, 5);
});

integrationTest('Integration Iter1: Swimming session', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('swimming', 1.0, 0.60, 0.30, 0.10)],
  }));
  assertEquals(status, 200);

  assert((data.carb_g as number) > 300, 'Carbs should exceed baseline');
  assert((data.session_kcal as number) > 0);
  assertEquals(data.algorithm_version, 'v6.0.0');
});

// ============================================================================
// Iteration 2: Multi-day context
// ============================================================================

integrationTest('Integration Iter2: Recovery debt from yesterday', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    yesterday_tss: 208,
    yesterday_hours_since: 16,
  }));
  assertEquals(status, 200);

  // Recovery adds 1.25 * 75 = 93.75g carb
  assertWithinPercent(data.carb_g as number, 394, 10);
  assertWithinPercent(data.prot_g as number, 123, 10);
});

integrationTest('Integration Iter2: Pre-race carb loading', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    tomorrow_is_race: true,
  }));
  assertEquals(status, 200);

  // Race pre-load: max(currentCarb, 9.0 * 75) = max(300, 675) = 675
  assertWithinPercent(data.carb_g as number, 675, 5);
});

integrationTest('Integration Iter2: Build phase modifier', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
    training_phase: 'build',
  }));
  assertEquals(status, 200);

  // Build: carb * 1.08, prot * 1.05. On a fat-capped day step 10b conserves
  // energy, so the extra protein kcal come out of carb: prot up, carb down.
  const baseResult = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
    training_phase: 'base',
  }));

  assert((data.prot_g as number) > (baseResult.data.prot_g as number), 'Build phase should have higher protein');
  assert((data.carb_g as number) <= (baseResult.data.carb_g as number), 'Fat-capped carbs absorb the protein increase');
  assertEquals(data.tdee, baseResult.data.tdee);
});

integrationTest('Integration Iter2: Taper de-load', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    training_phase: 'taper',
    weekly_hours_ratio: 0.75,
  }));
  assertEquals(status, 200);

  // Taper: carb * 0.88, weekly deload: carb - 0.5 * 75 → 231 pre-cap; the
  // 30 %E fat cap then lifts carb back to the energy-conserving 322.
  assertWithinPercent(data.carb_g as number, 322, 2);
});

integrationTest('Integration Iter2: All layers stacked (pre-race)', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.40, 0.40, 0.20)],
    yesterday_tss: 220,
    yesterday_hours_since: 20,
    tomorrow_is_race: true,
    training_phase: 'peak',
    weekly_hours_ratio: 1.25,
  }));
  assertEquals(status, 200);

  assertWithinPercent(data.carb_g as number, 798, 10);
  assertWithinPercent(data.prot_g as number, 159, 10);
  assertEquals(data.fat_g, 60); // fat floor
});

// ============================================================================
// Iteration 3: NEAT + TEF + TDEE
// ============================================================================

integrationTest('Integration Iter3: TDEE increases with training', async () => {
  const rest = await callEdgeFunction(refInput());
  const training = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  }));
  const hard = await callEdgeFunction(refInput({
    sessions: [session('cycling', 3.0, 0.30, 0.40, 0.30)],
  }));

  assertEquals(rest.status, 200);
  assertEquals(training.status, 200);
  assertEquals(hard.status, 200);

  assert(
    (rest.data.tdee as number) < (training.data.tdee as number),
    'Training TDEE > rest TDEE',
  );
  assert(
    (training.data.tdee as number) < (hard.data.tdee as number),
    'Hard TDEE > training TDEE',
  );
});

integrationTest('Integration Iter3: Lifestyle affects TDEE', async () => {
  const desk = await callEdgeFunction(refInput({ lifestyle: 'desk' }));
  const active = await callEdgeFunction(refInput({ lifestyle: 'active' }));

  assertEquals(desk.status, 200);
  assertEquals(active.status, 200);

  assert(
    (desk.data.tdee as number) < (active.data.tdee as number),
    'Active lifestyle should have higher TDEE',
  );
  assert(
    (desk.data.neat_kcal as number) < (active.data.neat_kcal as number),
    'Active should have higher NEAT',
  );
});

integrationTest('Integration Iter3: Fat floor holds at high carb', async () => {
  // Need aggressive inputs to push carbs high enough that fat hits floor
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.40, 0.40, 0.20)],
    yesterday_tss: 220,
    yesterday_hours_since: 20,
    tomorrow_is_race: true,
    training_phase: 'peak',
    weekly_hours_ratio: 1.25,
  }));
  assertEquals(status, 200);

  assertEquals(data.fat_g, 60); // 0.8 * 75 = 60
});

// ============================================================================
// Iteration 4: Safety + Carb cycling + Multi-session
// ============================================================================

integrationTest('Integration Iter4: EA check is present', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  }));
  assertEquals(status, 200);

  assert(typeof data.ea === 'number', 'EA should be a number');
  assert(typeof data.ea_status === 'string', 'EA status should be a string');
  assert(['OK', 'SOFT_WARNING', 'HARD_WARNING'].includes(data.ea_status as string));
});

integrationTest('Integration Iter4: Carb cycling converges under the fat cap', async () => {
  const withCycling = await callEdgeFunction(refInput({
    sessions: [session('running', 0.75, 1.0, 0, 0)],
    carb_cycle_opt_in: true,
    training_phase: 'base',
  }));
  const withoutCycling = await callEdgeFunction(refInput({
    sessions: [session('running', 0.75, 1.0, 0, 0)],
    carb_cycle_opt_in: false,
    training_phase: 'base',
  }));

  assertEquals(withCycling.status, 200);
  assertEquals(withoutCycling.status, 200);

  // On an easy day the 30 %E fat cap binds and step 10b reroutes the excess
  // to carb, so both plans land on the same energy-conserving carb figure.
  assertEquals(withCycling.data.carb_g, withoutCycling.data.carb_g);
  assertEquals(withCycling.data.tdee, withoutCycling.data.tdee);
});

integrationTest('Integration Iter4: Multi-session brick workout', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [
      session('cycling', 2.0, 0.30, 0.40, 0.30),
      session('running', 0.75, 0.60, 0.30, 0.10),
    ],
  }));
  assertEquals(status, 200);

  assert((data.carb_g as number) > 300, 'Brick carbs should exceed baseline');
  assert((data.session_kcal as number) > 0);
  assert((data.prot_g as number) >= 115, 'Protein should include bump');
});

integrationTest('Integration Iter4: Clamp ceiling (carb ≤ 12g/kg)', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.40, 0.40, 0.20)],
    yesterday_tss: 200,
    yesterday_hours_since: 16,
    tomorrow_is_race: true,
    training_phase: 'peak',
    weekly_hours_ratio: 1.35,
  }));
  assertEquals(status, 200);

  assert((data.carb_g as number) <= 900, 'Carbs should not exceed 12 * 75 = 900');
});

integrationTest('Integration Iter4: Clamp floor (carb ≥ 3g/kg)', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    training_phase: 'off_season',
    weekly_hours_ratio: 0.50,
  }));
  assertEquals(status, 200);

  assert((data.carb_g as number) >= 225, 'Carbs should not go below 3 * 75 = 225');
});

// ============================================================================
// Output shape
// ============================================================================

integrationTest('Integration: Response includes all required fields', async () => {
  const { status, data } = await callEdgeFunction(refInput());
  assertEquals(status, 200);

  assertEquals(typeof data.carb_g, 'number');
  assertEquals(typeof data.prot_g, 'number');
  assertEquals(typeof data.fat_g, 'number');
  assertEquals(typeof data.tdee, 'number');
  assertEquals(typeof data.rmr, 'number');
  assertEquals(typeof data.session_kcal, 'number');
  assertEquals(typeof data.neat_kcal, 'number');
  assertEquals(typeof data.tef_kcal, 'number');
  assertEquals(typeof data.mode, 'string');
  assertEquals(typeof data.ea, 'number');
  assertEquals(typeof data.ea_status, 'string');
  assertEquals(data.energy_basis, 'as_computed');
  // Delta is always present: null outside retrospective recalculation.
  assertEquals(data.delta, null);
  assertEquals(data.algorithm_version, 'v6.0.0');
});

integrationTest('Integration: Mode passes through', async () => {
  const prospective = await callEdgeFunction(refInput({ mode: 'prospective' }));
  const retrospective = await callEdgeFunction(refInput({ mode: 'retrospective' }));

  assertEquals(prospective.data.mode, 'prospective');
  assertEquals(retrospective.data.mode, 'retrospective');
});

// ============================================================================
// Female athlete
// ============================================================================

integrationTest('Integration: Female athlete produces valid output', async () => {
  const { status, data } = await callEdgeFunction({
    sex: 'female',
    age: 29,
    weight_kg: 62,
    height_cm: 165,
    body_fat_pct: 22,
    lifestyle: 'mixed',
    typical_weekly_hours: 8,
    carb_cycle_opt_in: false,
    training_phase: 'base',
    sessions: [session('running', 1.0, 0.80, 0.15, 0.05)],
    yesterday_tss: null,
    yesterday_hours_since: null,
    tomorrow_tss: null,
    tomorrow_duration_hr: null,
    tomorrow_is_race: false,
    weekly_hours_ratio: 1.0,
    mode: 'prospective',
  });
  assertEquals(status, 200);

  // Sanity checks for female athlete
  assert((data.carb_g as number) > 150 && (data.carb_g as number) < 600, `Carb_g out of range: ${data.carb_g}`);
  assert((data.prot_g as number) > 60 && (data.prot_g as number) < 200, `Prot_g out of range: ${data.prot_g}`);
  assert((data.fat_g as number) > 40 && (data.fat_g as number) < 200, `Fat_g out of range: ${data.fat_g}`);
  assert((data.tdee as number) > 1500 && (data.tdee as number) < 4000, `TDEE out of range: ${data.tdee}`);
  assert((data.rmr as number) > 1000 && (data.rmr as number) < 2000, `RMR out of range: ${data.rmr}`);
});

// ============================================================================
// No body fat (Mifflin fallback)
// ============================================================================

integrationTest('Integration: No body fat uses Mifflin fallback', async () => {
  const { status, data } = await callEdgeFunction(refInput({ body_fat_pct: null }));
  assertEquals(status, 200);

  // Mifflin RMR ≈ 1698 vs Cunningham 1908, so TDEE should be lower
  assertWithinPercent(data.rmr as number, 1698, 5);
  // Protein without LBM: 1.4 * 75 = 105
  assertWithinPercent(data.prot_g as number, 105, 5);
});

// ============================================================================
// Masters athlete (age ≥ 45)
// ============================================================================

integrationTest('Integration: Masters athlete gets protein bump', async () => {
  const young = await callEdgeFunction(refInput({ age: 34 }));
  const masters = await callEdgeFunction(refInput({ age: 50 }));

  assertEquals(young.status, 200);
  assertEquals(masters.status, 200);

  // Masters: 1.15x protein multiplier
  assert(
    (masters.data.prot_g as number) > (young.data.prot_g as number),
    'Masters athlete should have higher protein',
  );
});
