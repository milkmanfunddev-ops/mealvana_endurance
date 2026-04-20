/**
 * Integration tests for calculate-daily-macros Edge Function
 *
 * Calls the deployed edge function via HTTP to verify end-to-end behavior.
 * Mirrors the unit/pipeline tests in index.test.ts but exercises the full
 * HTTP stack: CORS, JSON parsing, validation, calculation, and response.
 *
 * Run with:
 *   export SUPABASE_URL=https://vlmtsdzpnjnavdgytcmi.supabase.co
 *   export SUPABASE_ANON_KEY=<dev-anon-key>
 *   deno test --allow-net --allow-env supabase/functions/calculate-daily-macros/index.integration.test.ts
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
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/calculate-daily-macros`;

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

Deno.test('Integration: Edge function is reachable', async () => {
  assert(SUPABASE_URL.length > 0, 'SUPABASE_URL must be set');
  assert(SUPABASE_ANON_KEY.length > 0, 'SUPABASE_ANON_KEY must be set');

  const { status } = await callEdgeFunction(refInput());
  assertEquals(status, 200);
});

// ============================================================================
// Validation (HTTP layer)
// ============================================================================

Deno.test('Integration: Rejects GET method', async () => {
  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
  });
  assertEquals(response.status, 405);
  await response.json(); // consume body
});

Deno.test('Integration: Rejects invalid JSON', async () => {
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

Deno.test('Integration: Returns validation error for missing sex', async () => {
  const { status, data } = await callEdgeFunction({ weight_kg: 75, height_cm: 178, age: 34, sessions: [] });
  assertEquals(status, 400);
  assert(typeof data.error === 'string');
});

Deno.test('Integration: Returns validation error for bad zones', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.0, 0.70, 0.20, 0.20)], // sums to 1.1
  }));
  assertEquals(status, 400);
  assert((data.error as string).includes('sum to 1.0'));
});

Deno.test('Integration: Returns validation error for invalid sport', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('hiking', 1.0, 0.70, 0.20, 0.10)],
  }));
  assertEquals(status, 400);
  assert(typeof data.error === 'string');
});

// ============================================================================
// Iteration 1: Baseline + Session
// ============================================================================

Deno.test('Integration Iter1: Rest day (no sessions)', async () => {
  const { status, data } = await callEdgeFunction(refInput());
  assertEquals(status, 200);

  assertWithinPercent(data.carb_g as number, 300, 5);
  assertWithinPercent(data.prot_g as number, 115, 5);
  assertWithinPercent(data.fat_g as number, 93, 15);
  assertWithinPercent(data.tdee as number, 2501, 5);
  assertEquals(data.session_kcal, 0);
  assertEquals(data.mode, 'prospective');
  assertEquals(data.algorithm_version, 'v4.0.0');
});

Deno.test('Integration Iter1: 90-min run', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  }));
  assertEquals(status, 200);

  // Zones 0.70/0.20/0.10 → IF ≈ 0.771
  assertWithinPercent(data.carb_g as number, 376, 5);
  assertWithinPercent(data.prot_g as number, 130, 5);
  assertWithinPercent(data.session_kcal as number, 1309, 5);
  assert((data.ea as number) > 30, 'EA should be above 30 for normal training');
});

Deno.test('Integration Iter1: 4hr bike ride', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('cycling', 4.0, 0.60, 0.30, 0.10)],
  }));
  assertEquals(status, 200);

  // Zones 0.60/0.30/0.10 → IF ≈ 0.791
  assertWithinPercent(data.carb_g as number, 547, 5);
  assertWithinPercent(data.prot_g as number, 130, 5);
  assertWithinPercent(data.session_kcal as number, 3007, 5);
});

Deno.test('Integration Iter1: Strength session', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('strength', 1.0, 0.70, 0.20, 0.10)],
  }));
  assertEquals(status, 200);

  assertWithinPercent(data.carb_g as number, 351, 5);
  assertWithinPercent(data.prot_g as number, 138, 5);
  assertWithinPercent(data.session_kcal as number, 386, 5);
});

Deno.test('Integration Iter1: Swimming session', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('swimming', 1.0, 0.60, 0.30, 0.10)],
  }));
  assertEquals(status, 200);

  assert((data.carb_g as number) > 300, 'Carbs should exceed baseline');
  assert((data.session_kcal as number) > 0);
  assertEquals(data.algorithm_version, 'v4.0.0');
});

// ============================================================================
// Iteration 2: Multi-day context
// ============================================================================

Deno.test('Integration Iter2: Recovery debt from yesterday', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    yesterday_tss: 208,
    yesterday_hours_since: 16,
  }));
  assertEquals(status, 200);

  // Recovery adds 1.25 * 75 = 93.75g carb
  assertWithinPercent(data.carb_g as number, 394, 10);
  assertWithinPercent(data.prot_g as number, 123, 10);
});

Deno.test('Integration Iter2: Pre-race carb loading', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    tomorrow_is_race: true,
  }));
  assertEquals(status, 200);

  // Race pre-load: max(currentCarb, 9.0 * 75) = max(300, 675) = 675
  assertWithinPercent(data.carb_g as number, 675, 5);
});

Deno.test('Integration Iter2: Build phase modifier', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
    training_phase: 'build',
  }));
  assertEquals(status, 200);

  // Build: carb * 1.08, prot * 1.05
  const baseResult = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
    training_phase: 'base',
  }));

  assert((data.carb_g as number) > (baseResult.data.carb_g as number), 'Build phase should have higher carbs');
  assert((data.prot_g as number) > (baseResult.data.prot_g as number), 'Build phase should have higher protein');
});

Deno.test('Integration Iter2: Taper de-load', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    training_phase: 'taper',
    weekly_hours_ratio: 0.75,
  }));
  assertEquals(status, 200);

  // Taper: carb * 0.88, weekly deload: carb - 0.5 * 75
  assertWithinPercent(data.carb_g as number, 231, 10);
});

Deno.test('Integration Iter2: All layers stacked (pre-race)', async () => {
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

Deno.test('Integration Iter3: TDEE increases with training', async () => {
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

Deno.test('Integration Iter3: Lifestyle affects TDEE', async () => {
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

Deno.test('Integration Iter3: Fat floor holds at high carb', async () => {
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

Deno.test('Integration Iter4: EA check is present', async () => {
  const { status, data } = await callEdgeFunction(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  }));
  assertEquals(status, 200);

  assert(typeof data.ea === 'number', 'EA should be a number');
  assert(typeof data.ea_status === 'string', 'EA status should be a string');
  assert(['OK', 'SOFT_WARNING', 'HARD_WARNING'].includes(data.ea_status as string));
});

Deno.test('Integration Iter4: Carb cycling reduces easy day carbs', async () => {
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

  assert(
    (withCycling.data.carb_g as number) < (withoutCycling.data.carb_g as number),
    'Carb cycling should reduce carbs on easy days',
  );
});

Deno.test('Integration Iter4: Carb cycling disabled in peak phase', async () => {
  const base = await callEdgeFunction(refInput({
    sessions: [session('running', 0.75, 1.0, 0, 0)],
    carb_cycle_opt_in: true,
    training_phase: 'base',
  }));
  const peak = await callEdgeFunction(refInput({
    sessions: [session('running', 0.75, 1.0, 0, 0)],
    carb_cycle_opt_in: true,
    training_phase: 'peak',
  }));

  assertEquals(base.status, 200);
  assertEquals(peak.status, 200);

  // Peak disables carb cycling, so carb_g should be higher (despite peak modifier)
  // Peak modifier is 1.12, base is 1.0 — peak carb_g = baseline * 1.12, base carb_g = 3.0 * 75 (cycled)
  // 300 * 1.12 = 336 > 225 + session_carb
  assert(
    (peak.data.carb_g as number) > (base.data.carb_g as number),
    'Peak should not apply cycling, so carbs should be higher',
  );
});

Deno.test('Integration Iter4: Multi-session brick workout', async () => {
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

Deno.test('Integration Iter4: Clamp ceiling (carb ≤ 12g/kg)', async () => {
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

Deno.test('Integration Iter4: Clamp floor (carb ≥ 3g/kg)', async () => {
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

Deno.test('Integration: Response includes all required fields', async () => {
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
  assertEquals(data.algorithm_version, 'v4.0.0');
});

Deno.test('Integration: Mode passes through', async () => {
  const prospective = await callEdgeFunction(refInput({ mode: 'prospective' }));
  const retrospective = await callEdgeFunction(refInput({ mode: 'retrospective' }));

  assertEquals(prospective.data.mode, 'prospective');
  assertEquals(retrospective.data.mode, 'retrospective');
});

// ============================================================================
// Female athlete
// ============================================================================

Deno.test('Integration: Female athlete produces valid output', async () => {
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

Deno.test('Integration: No body fat uses Mifflin fallback', async () => {
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

Deno.test('Integration: Masters athlete gets protein bump', async () => {
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
