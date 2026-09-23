/** The Vana evals trace harness — runs scenario conversations through the REAL runChat pipeline against a fake
 *  database, the real Haiku model through the gateway, and writes one JSONL line per turn: the full TurnTrace
 *  (persona, Doll, model messages, tools, steps with raw text and tool inputs/outputs) plus the NDJSON the app
 *  would have streamed. Usage and the loading/dumping workflow live in evals/vana/README.md.
 *
 *  Run:  deno run -A supabase/functions/evals/vana/run.ts [--only S03] [--limit 5] [--out <file>] [--scenarios <file>]
 *  Key:  AI_GATEWAY_API_KEY_EVALS (preferred) or AI_GATEWAY_API_KEY, or secrets/ai_gateway.env — found by walking up.
 *  Cost: one Haiku turn each; the wallet and the dev database are never touched (fake db, no reserveBudget). */
import { runChat, type TurnTrace } from '../../_shared/vana/chat.ts';
import { cacheReadTokens } from '../../_shared/vana/stream.ts';
import { fakeDb } from '../../tests/vana/support/fake_db.ts';
import { VANA_COLUMN_DEFAULTS, TEST_USER_ID as SUPPORT_USER } from '../../tests/vana/support/vana_ctx.ts';
import { seedTables, rpcHandlers, ANCHOR, type ProfileKey } from './profiles.ts';

interface Scenario {
  id: string; task: string; athlete: ProfileKey; character: string;
  kind?: 'meal_planning' | 'general';
  seed?: { existing_plan?: boolean; awaiting_debrief?: boolean };
  turns: string[];
}

// ---------------------------------------------------------------- args + env
const args = new Map(Deno.args.filter((a) => a.startsWith('--')).map((a) => { const [k, ...v] = a.replace(/^--/, '').split('='); return [k, v.join('=')] as const; }));
// Space-separated values too (--only S06), not just --only=S06.
for (let i = 0; i < Deno.args.length - 1; i++) if (Deno.args[i].startsWith('--') && !Deno.args[i].includes('=')) { const k = Deno.args[i].slice(2); if (Deno.args[i + 1] && !Deno.args[i + 1].startsWith('--')) args.set(k, Deno.args[i + 1]); }
const flag = (k: string) => Deno.args.includes(`--${k}`);

const repoRoot = (() => {
  let d = new URL('.', import.meta.url);
  for (let i = 0; i < 8; i++) {
    const p = decodeURIComponent(d.pathname);
    try { Deno.statSync(`${p}secrets/ai_gateway.env`); return p.replace(/\/$/, ''); } catch { /* keep walking */ }
    d = new URL('..', d);
  }
  throw new Error('could not find the repo root (secrets/ai_gateway.env) walking up from the harness');
})();

const gatewayKey = (env: string): string | null => {
  const fromEnv = Deno.env.get(env);
  if (fromEnv) return fromEnv;
  try {
    const txt = Deno.readTextFileSync(`${repoRoot}/secrets/ai_gateway.env`);
    const m = txt.match(new RegExp(`^${env}=(.+)$`, 'm'));
    return m ? m[1].trim() : null;
  } catch { return null; }
};
const key = gatewayKey('AI_GATEWAY_API_KEY_EVALS') ?? gatewayKey('AI_GATEWAY_API_KEY');
if (!key) throw new Error('no gateway key: export AI_GATEWAY_API_KEY_EVALS or keep it in secrets/ai_gateway.env');
Deno.env.set('AI_GATEWAY_API_KEY', key);

const scenariosPath = args.get('scenarios') ?? `${repoRoot}/evals/vana/scenarios/v1.json`;
const runId = `run-${new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14)}`;
const outPath = args.get('out') ?? `${repoRoot}/evals/vana/traces/${runId}.jsonl`;
const scenarios: Scenario[] = JSON.parse(Deno.readTextFileSync(scenariosPath));
const selected = (args.get('only') ? scenarios.filter((s) => args.get('only')!.split(',').includes(s.id)) : scenarios)
  .slice(0, args.get('limit') ? Number(args.get('limit')) : scenarios.length);
if (!selected.length) throw new Error(`no scenarios selected from ${scenariosPath}`);

Deno.mkdirSync(`${repoRoot}/evals/vana/traces`, { recursive: true });
const out = await Deno.open(outPath, { write: true, create: true, truncate: true });

// ---------------------------------------------------------------- the run
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
/** Wait for the turn to be fully settled: the trace handed over AND the assistant row landed on the fake db
 *  (runChat's persistence runs detached under waitUntil locally, so the next turn must not race it). */
async function settled(fake: ReturnType<typeof fakeDb>, traces: TurnTrace[], prevAssistant: number, ms = 20_000) {
  const assistantRows = () => (fake.tables.vana_messages ?? []).filter((r) => r.role === 'assistant').length;
  for (const end = Date.now() + ms; Date.now() < end;) {
    if (traces.length && assistantRows() > prevAssistant) return;
    await sleep(20);
  }
}

let turns = 0, inTok = 0, outTok = 0;
console.log(`[evals] ${selected.length} scenario(s) -> ${outPath} (anchor ${ANCHOR})`);
for (const s of selected) {
  const tables = seedTables(s.athlete, { currentPlan: s.seed?.existing_plan, lastWeekPlan: s.seed?.awaiting_debrief });
  let fake!: ReturnType<typeof fakeDb>;
  fake = fakeDb(tables, { rpc: rpcHandlers(() => fake), defaults: { ...VANA_COLUMN_DEFAULTS, meal_feedback: {}, saved_meals: { is_deleted: false }, plan_debriefs: {}, onboarding_surveys: {}, user_entitlements: {}, events: {}, activities: {}, daily_macro_targets: {} } });
  // deno-lint-ignore no-explicit-any
  const db = fake as any;
  const v = { db, admin: db, userId: SUPPORT_USER, token: 'eval-harness' };
  let conversationId: string | null = null;

  for (let i = 0; i < s.turns.length; i++) {
    const traces: TurnTrace[] = [];
    const prevAssistant = (fake.tables.vana_messages ?? []).filter((r) => r.role === 'assistant').length;
    const t0 = Date.now();
    const outcome = await runChat(v, { message: s.turns[i], conversation_id: conversationId, kind: s.kind ?? 'meal_planning', timezone: 'America/Chicago', anchor_date: ANCHOR, input_mode: 'typed' }, { functionName: 'evals-vana', onTrace: (t) => traces.push(t) });
    turns++;
    if (!outcome.ok) {
      console.warn(`[evals] ${s.id} turn ${i + 1}: refused (${JSON.stringify(outcome.body)})`);
      const line = { run_id: runId, source: 'synthetic', scenario_id: s.id, task: s.task, athlete: s.athlete, character: s.character, turn: i + 1, model: null, input_tokens: null, output_tokens: null, cache_read_tokens: null, duration_ms: Date.now() - t0, error: `refused:${outcome.status}`, payload: { scenario: s, body: outcome.body } };
      out.write(new TextEncoder().encode(JSON.stringify(line) + '\n'));
      continue;
    }
    conversationId ??= outcome.response.headers.get('x-conversation-id');
    const ndjson = await outcome.response.text();
    await settled(fake, traces, prevAssistant);
    const trace = traces[0];
    if (!trace) { console.warn(`[evals] ${s.id} turn ${i + 1}: no trace landed (stream error?)`); continue; }
    const u = (trace.totalUsage ?? trace.usage ?? {}) as { inputTokens?: number; outputTokens?: number };
    inTok += u.inputTokens ?? 0; outTok += u.outputTokens ?? 0;
    const line = {
      run_id: runId, source: 'synthetic', scenario_id: s.id, task: s.task, athlete: s.athlete, character: s.character, turn: i + 1,
      model: trace.model, input_tokens: u.inputTokens ?? null, output_tokens: u.outputTokens ?? null, cache_read_tokens: cacheReadTokens(trace.totalUsage ?? trace.usage) ?? null,
      duration_ms: trace.durationMs, error: trace.error ?? null,
      payload: { ...trace, ndjson: ndjson.split('\n').filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return l; } }) },
    };
    out.write(new TextEncoder().encode(JSON.stringify(line) + '\n'));
    // Tool calls ride on `step.toolCalls` or as `tool-call` parts of `step.content`, depending on the step — read both.
    const calls = ((trace.steps ?? []) as unknown[]).flatMap((st) => {
      const s = st as { toolCalls?: { toolName?: string }[]; content?: unknown };
      const fromCalls = (s.toolCalls ?? []).map((c) => c.toolName);
      const fromContent = Array.isArray(s.content) ? s.content.flatMap((p) => (p && typeof p === 'object' && (p as { type?: string }).type === 'tool-call' ? [(p as { toolName?: string }).toolName] : [])) : [];
      return [...fromCalls, ...fromContent];
    }).filter(Boolean);
    console.log(`[evals] ${s.id}.${i + 1} ${trace.error ? 'ERROR ' + trace.error : `${u.inputTokens ?? 0}in/${u.outputTokens ?? 0}out ${trace.durationMs}ms tools=[${calls.join(',')}]`}`);
  }
}
out.close();
const cost = (inTok * 1 + outTok * 5) / 1_000_000; // Haiku list, $/MTok — a rough ceiling (cache reads are cheaper)
console.log(`[evals] done: ${turns} turn(s), ${inTok.toLocaleString()} in / ${outTok.toLocaleString()} out tokens, ≈$${cost.toFixed(3)} at Haiku list`);
console.log(`[evals] load to dev:  node evals/vana/scripts/load.mjs ${outPath}`);
