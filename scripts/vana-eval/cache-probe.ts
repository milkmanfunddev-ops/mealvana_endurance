#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write --allow-env --allow-sys
/**
 * cache-probe — ten planning turns straight at the AI Gateway, measuring what each turn's FIRST model step reads from
 * Anthropic's prompt cache (ai-cost ticket 07, mp-420 clauses 4 and 5, mp-290 clause 3).
 *
 * The prompt is shaped like a real planning turn: the real tool list (tools.ts over the fake database, so nothing is
 * written anywhere), the real persona, a realistic athlete context, the real opener as the first user message, and the
 * Situation line on the newest message. The athlete context is REBUILT before turns 4, 6 and 8, the way a plan write
 * rebuilds it in production (context-cache.ts invalidateContext) — that churn is what the split shape has to survive.
 *
 * Shapes:
 *   --shape today   one system string (persona + context) with Anthropic's automatic cache_control, as chat.ts sent it
 *                   up to wave 4. `--caching auto` adds the gateway's own automatic caching to it (the ticket's first,
 *                   one-line experiment).
 *   --shape split   two system messages, persona then context, each with an explicit marker (the persona's at the
 *                   one-hour lifetime unless `--ttl none`), the call pinned to Anthropic and carrying a session id per
 *                   conversation — the shape chat.ts sends since ticket 07 (systemMessages / chatProviderOptions).
 *
 * Spend: ten Haiku turns, each capped at two steps and 400 output tokens — a few cents. It spends the EVALS key
 * (`AI_GATEWAY_API_KEY_EVALS`, ticket 02), never dev's or production's.
 *
 * Usage:
 *   deno run -A scripts/vana-eval/cache-probe.ts --shape today --caching auto --out .scratch/probe-today.json
 *   deno run -A scripts/vana-eval/cache-probe.ts --shape split --out .scratch/probe-split.json
 */
import { evalsGatewayKeyFromRepo } from './gateway-key.ts';
import { PLANNING_PROMPT, OPENERS } from '../../supabase/functions/_shared/vana/persona.ts';
import { contextBlock } from '../../supabase/functions/_shared/vana/context.ts';
import { makeVanaTools } from '../../supabase/functions/_shared/vana/tools.ts';
import { testCtx } from '../../supabase/functions/tests/vana/support/vana_ctx.ts';
import type { AthleteContext } from '../../supabase/functions/_shared/vana/contracts.ts';

const args = new Map<string, string>();
for (let i = 0; i < Deno.args.length; i++) { const m = Deno.args[i].match(/^--([^=]+)(?:=(.*))?$/); if (!m) continue; const next = Deno.args[i + 1]; if (m[2] != null) args.set(m[1], m[2]); else if (next && !next.startsWith('--')) { args.set(m[1], next); i++; } else args.set(m[1], 'true'); }
const shape = args.get('shape') === 'split' ? 'split' : 'today';
const gatewayAuto = args.get('caching') === 'auto';
const ttl = args.get('ttl') === 'none' ? null : '1h';
const out = args.get('out') ?? null;
const MODEL = 'anthropic/claude-haiku-4.5';
const ANCHOR = '2026-09-22';
const SESSION = `probe-${crypto.randomUUID()}`;

const key = evalsGatewayKeyFromRepo();
if (!key) { console.error('cache-probe: no evals gateway key; export AI_GATEWAY_API_KEY_EVALS'); Deno.exit(2); }
Deno.env.set('AI_GATEWAY_API_KEY', key);
const { streamText, stepCountIs } = await import('npm:ai@6.0.277');
// The production helpers, imported after the key is set so the SDK module they load reads it.
const chat = await import('../../supabase/functions/_shared/vana/chat.ts');

// ---------------------------------------------------------------- a realistic athlete (the shape context.ts builds)
const day = (d: number) => `2026-09-${String(d).padStart(2, '0')}`;
const targets = Array.from({ length: 7 }, (_, i) => ({ date: day(22 + i), kcal: 3050 + i * 40, carbsG: 410 + i * 8, proteinG: 145, fatG: 72, sessionKcal: 620, planningKcal: 2430 + i * 40, lunchDinnerKcal: 1336 + i * 22, mode: 'fuel' }));
function athlete(plan: AthleteContext['plan']): AthleteContext {
  return {
    profile: { firstName: 'Lee', diet: 'vegetarian', allergies: ['peanuts'], gutTraining: 'moderate' },
    week: { start: '2026-09-20', periodDays: 7, character: 'high load', anchor: 'Saturday: Long ride 180m', loadScore: 7.5, workouts: [
      { date: day(22), title: 'Easy run', type: 'running', minutes: 45, intensity: 'easy' },
      { date: day(24), title: 'Hill repeats', type: 'running', minutes: 70, intensity: 'high' },
      { date: day(26), title: 'Long ride', type: 'cycling', minutes: 180, intensity: 'moderate' },
      { date: day(27), title: 'Brick run', type: 'running', minutes: 40, intensity: 'moderate' },
    ] },
    race: { name: 'Chattanooga 70.3', date: '2026-10-18', daysOut: 26, location: 'Chattanooga, TN' },
    budget: { today: targets[0], week: targets, raceWeekCarbsG: null },
    weather: { today: 'Birmingham: 84°F, sunny, humid', raceDay: null },
    holidays: [],
    loggedToday: { count: 2, carbsG: 120 },
    plan,
    memories: [
      { id: 'm1', kind: 'preference', fact: 'Hates cilantro', confidence: 0.9, lastConfirmedAt: '2026-09-05T10:00:00Z', source: 'conversation' },
      { id: 'm2', kind: 'pattern', fact: 'Wednesdays are chaos: no time to cook', confidence: 0.8, lastConfirmedAt: '2026-09-12T10:00:00Z', source: 'conversation' },
      { id: 'm3', kind: 'constraint', fact: 'Partner eats no mushrooms', confidence: 0.9, lastConfirmedAt: '2026-09-14T10:00:00Z', source: 'conversation' },
    ] as AthleteContext['memories'],
    lastTalks: [{ date: '2026-09-19', fact: 'Planned three batch dinners around the Saturday long ride with Marco.' }],
    recentSession: { date: day(20), title: 'Century ride', type: 'cycling', minutes: 300, intensity: 'moderate', status: 'completed' },
    season: ['apples', 'butternut squash', 'kale', 'sweet potatoes'],
    grocery: { weeklyUsd: null },
    lastWeek: { completed: 5, planned: 7, skipReason: 'travel', weekStart: '2026-09-13' },
    likes: [{ name: 'Lentil bolognese', stance: 'up' }, { name: 'Tofu stir-fry', stance: 'down' }],
    goals: ['Finish Chattanooga 70.3 under 6 hours'],
    home: { city: 'Birmingham, Alabama', lat: 33.52, lon: -86.8, timezone: 'America/Chicago' },
  };
}
/** The PLAN line as it changes when the athlete taps meals or answers a fork: the context rebuild the cache must survive. */
const PLANS: Record<number, AthleteContext['plan']> = {
  1: { exists: false, status: null, mealsLeft: null, batchCooking: true, batchKnown: false, coverageScope: null, mealTypes: null },
  4: { exists: true, status: 'draft', mealsLeft: 8, batchCooking: true, batchKnown: false, coverageScope: null, mealTypes: null },
  6: { exists: true, status: 'draft', mealsLeft: 12, batchCooking: true, batchKnown: false, coverageScope: null, mealTypes: null },
  8: { exists: true, status: 'draft', mealsLeft: 12, batchCooking: true, batchKnown: true, coverageScope: 'dinners_lunches', mealTypes: null },
};
const SITUATION = 'looking at the Plan tab; no plan for the week of 2026-09-20 yet';
const TURNS: string[] = [
  OPENERS.meal_planning,
  "Something new — I'm bored of my usual dinners",
  'Chickpeas or tofu, either works',
  'I like these',
  'Other options',
  'Next: lunch',
  'Cook once and eat it across the week',
  'Dinners and lunches',
  "Why lentils before Thursday's hill repeats?",
  "That's my week",
];

// ---------------------------------------------------------------- the call
const v = testCtx({ meal_plans: [], plan_meals: [], user_memories: [], meal_logs: [], saved_meals: [] }, { rpc: { search_meals: () => [] } });
const tools = makeVanaTools(v, athlete(PLANS[1]), 'meal_planning', { scope: null, conversationId: SESSION, shownIds: [] });
type Usage = { inputTokens?: number; outputTokens?: number; inputTokenDetails?: { cacheReadTokens?: number; cacheWriteTokens?: number; noCacheTokens?: number } };
type Row = { turn: number; rebuilt: boolean; steps: number; first: { input: number; cacheRead: number; cacheWrite: number; noCache: number; share: number }; turnInput: number; turnCacheRead: number; costUsd: number | null };
const rows: Row[] = [];
const rawMeta: Record<string, unknown> = {};
// deno-lint-ignore no-explicit-any
let history: any[] = [];
let ctx = athlete(PLANS[1]);
for (let t = 1; t <= TURNS.length; t++) {
  const rebuilt = t in PLANS && t > 1;
  if (rebuilt) ctx = athlete(PLANS[t]);
  const userText = TURNS[t - 1];
  const messages = chat.withSituation([...history, { role: 'user' as const, content: [{ type: 'text' as const, text: userText }] }], SITUATION, null);
  const system = shape === 'split' ? chat.systemMessages('meal_planning', ctx, ANCHOR, '', ttl) : `${PLANNING_PROMPT}\n--- CONTEXT (today ${ANCHOR}, Monday) ---\n${contextBlock(ctx)}`;
  const providerOptions = shape === 'split' ? chat.chatProviderOptions() : { ...chat.CACHE_PROVIDER_OPTIONS, ...(gatewayAuto ? { gateway: { caching: 'auto' as const } } : {}) };
  const headers = shape === 'split' ? chat.chatHeaders(SESSION) : undefined;
  const started = Date.now();
  // deno-lint-ignore no-explicit-any
  const result = streamText({ model: MODEL, system: system as any, messages, tools, maxOutputTokens: 400, stopWhen: stepCountIs(2), providerOptions, headers });
  let text = '';
  for await (const part of result.fullStream) { if (part.type === 'text-delta') text += part.text ?? ''; if (part.type === 'error') console.error('  stream error:', (part.error as Error)?.message ?? part.error); }
  const steps = await result.steps; const total = (await result.totalUsage) as Usage;
  const first = steps[0]?.usage as Usage | undefined;
  const fi = first?.inputTokens ?? 0; const fr = first?.inputTokenDetails?.cacheReadTokens ?? 0; const fw = first?.inputTokenDetails?.cacheWriteTokens ?? 0; const fn = first?.inputTokenDetails?.noCacheTokens ?? 0;
  const cost = steps.map((s) => { const g = (s.providerMetadata as { gateway?: { cost?: string | number } } | undefined)?.gateway?.cost; const n = typeof g === 'string' ? Number.parseFloat(g) : typeof g === 'number' ? g : NaN; return Number.isFinite(n) ? n : null; });
  const costUsd = cost.some((c) => c != null) ? cost.reduce((a, b) => (a ?? 0) + (b ?? 0), 0) : null;
  rows.push({ turn: t, rebuilt, steps: steps.length, first: { input: fi, cacheRead: fr, cacheWrite: fw, noCache: fn, share: fi ? fr / fi : 0 }, turnInput: total?.inputTokens ?? 0, turnCacheRead: total?.inputTokenDetails?.cacheReadTokens ?? 0, costUsd });
  if (t <= 2) rawMeta[`turn${t}`] = { firstStepUsage: first, firstStepProviderMetadata: steps[0]?.providerMetadata, responseHeaders: (await result.response).headers };
  console.log(`turn ${String(t).padStart(2)} ${rebuilt ? 'REBUILT' : '       '} steps=${steps.length} first: in=${fi} read=${fr} write=${fw} nocache=${fn} share=${(fi ? (100 * fr) / fi : 0).toFixed(1)}% · turn in=${total?.inputTokens} read=${total?.inputTokenDetails?.cacheReadTokens} · $${costUsd?.toFixed(5) ?? '?'} · ${Date.now() - started}ms · ${text.replace(/\s+/g, ' ').slice(0, 70)}`);
  // The next turn replays what the SDK produced, byte for byte — the equivalent of a stored conversation replayed as sent.
  const response = await result.response;
  history = [...messages, ...response.messages];
}
const firstShare = rows.reduce((s, r) => s + r.first.cacheRead, 0) / Math.max(1, rows.reduce((s, r) => s + r.first.input, 0));
const followUps = rows.slice(1);
const followShare = followUps.reduce((s, r) => s + r.first.cacheRead, 0) / Math.max(1, followUps.reduce((s, r) => s + r.first.input, 0));
const spend = rows.reduce((s, r) => s + (r.costUsd ?? 0), 0);
console.log(`\nshape=${shape}${gatewayAuto ? '+gateway-auto' : ''}${shape === 'split' ? ` ttl=${ttl ?? 'none'}` : ''} model=${MODEL}`);
console.log(`first-step read share: all ten turns ${(100 * firstShare).toFixed(1)}% · the nine follow-ups ${(100 * followShare).toFixed(1)}% · spend $${spend.toFixed(4)} · per turn $${(spend / rows.length).toFixed(4)}`);
if (out) { await Deno.writeTextFile(out, JSON.stringify({ shape, gatewayAuto, ttl: shape === 'split' ? ttl : null, model: MODEL, session: SESSION, rows, firstShare, followShare, spend, rawMeta }, null, 2)); console.log(`written ${out}`); }
