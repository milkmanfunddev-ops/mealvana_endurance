#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write --allow-env
/**
 * vana-eval personalization — does Vana actually know the person?
 *
 * The Voodoo Doll spec's Seam 2. Each case drives real conversations against the dev `vana-chat`
 * edge function as the eval user, then reads the rows back through PostgREST rather than trusting
 * anything the model said about itself. Every case records its own input and output tokens, so a
 * later model decision can be made with numbers instead of impressions.
 *
 * This BILLS real model spend and writes real rows (conversations, memories, feedback) for the eval
 * user. Never wire it into CI or the test runner; run it by hand.
 *
 * Usage:
 *   deno run -A scripts/vana-eval/personalization.ts
 *   deno run -A scripts/vana-eval/personalization.ts --only knows-tomorrow,logged-today
 *   deno run -A scripts/vana-eval/personalization.ts --list
 *   deno run -A scripts/vana-eval/personalization.ts --verbose --out personalization.json
 *
 * Credentials: same as run.ts — SUPABASE_URL + SUPABASE_ANON_KEY from `.env.dev.local`,
 * VANA_EVAL_EMAIL/PASSWORD falling back to INTEGRATION_TEST_EMAIL/PASSWORD from
 * `secrets/integration_test.env`. The eval user must be Pro.
 */

// ---------------------------------------------------------------- args + env
const args = new Map<string, string | true>();
for (let i = 0; i < Deno.args.length; i++) {
  const m = Deno.args[i].match(/^--([^=]+)(?:=(.*))?$/); if (!m) continue;
  const next = Deno.args[i + 1];
  if (m[2] != null) args.set(m[1], m[2]);
  else if (next && !next.startsWith('--')) { args.set(m[1], next); i++; }
  else args.set(m[1], true);
}
const verbose = args.has('verbose');
const only = typeof args.get('only') === 'string' ? String(args.get('only')).split(',').map((s) => s.trim()).filter(Boolean) : null;
const out = typeof args.get('out') === 'string' ? String(args.get('out')) : null;

function readEnvFile(path: string): Record<string, string> {
  try {
    const o: Record<string, string> = {};
    for (const line of Deno.readTextFileSync(path).split('\n')) { const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/); if (m) o[m[1]] = m[2].replace(/^["']|["']$/g, ''); }
    return o;
  } catch { return {}; }
}
const root = new URL('../../', import.meta.url).pathname;
const fileEnv = { ...readEnvFile(root + '.env.dev.local'), ...readEnvFile(root + 'secrets/integration_test.env') };
const env = (k: string, ...fallbacks: string[]) => { for (const key of [k, ...fallbacks]) { const v = Deno.env.get(key) ?? fileEnv[key]; if (v) return v; } return null; };
const SUPABASE_URL = env('SUPABASE_URL'); const ANON = env('SUPABASE_ANON_KEY');
const EMAIL = env('VANA_EVAL_EMAIL', 'INTEGRATION_TEST_EMAIL'); const PASSWORD = env('VANA_EVAL_PASSWORD', 'INTEGRATION_TEST_PASSWORD');
if (!SUPABASE_URL || !ANON || !EMAIL || !PASSWORD) { console.error('personalization: need SUPABASE_URL, SUPABASE_ANON_KEY, VANA_EVAL_EMAIL, VANA_EVAL_PASSWORD (see header)'); Deno.exit(2); }
// Dev only, and not by convention — by project ref. These cases write memories and feedback rows.
const DEV_REF = 'vlmtsdzpnjnavdgytcmi';
if (!SUPABASE_URL.includes(DEV_REF)) { console.error(`personalization: refusing to run against ${SUPABASE_URL} — dev (${DEV_REF}) only`); Deno.exit(2); }

// ---------------------------------------------------------------- transport
type Part = { kind: string; [k: string]: unknown };
export interface Exchange { say?: string; text: string; parts: Part[]; tools: string[]; error?: string; inputTokens: number; outputTokens: number }

async function signIn(): Promise<string> {
  const r = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: ANON!, 'content-type': 'application/json' }, body: JSON.stringify({ email: EMAIL, password: PASSWORD }) });
  if (!r.ok) { console.error('personalization: sign-in failed', r.status, await r.text()); Deno.exit(2); }
  return (await r.json()).access_token as string;
}

interface Session { jwt: string; userId: string }

async function chat(s: Session, body: Record<string, unknown>): Promise<{ conversationId: string | null; ex: Exchange }> {
  const r = await fetch(`${SUPABASE_URL}/functions/v1/vana-chat`, { method: 'POST', headers: { apikey: ANON!, authorization: `Bearer ${s.jwt}`, 'content-type': 'application/json' }, body: JSON.stringify({ timezone: Intl.DateTimeFormat().resolvedOptions().timeZone, ...body }) });
  if (r.status === 403) { console.error('personalization: 403 — the eval user is not Pro (pro_required)'); Deno.exit(2); }
  if (r.status === 429) { const j = await r.json().catch(() => ({})); const wait = Number(j.retry_after_seconds ?? 10); console.log(`  rate limited — waiting ${wait}s`); await new Promise((res) => setTimeout(res, wait * 1000)); return chat(s, body); }
  if (!r.ok) throw new Error(`vana-chat ${r.status}: ${await r.text()}`);
  const ex: Exchange = { say: body.message as string | undefined, text: '', parts: [], tools: [], inputTokens: 0, outputTokens: 0 };
  for (const line of (await r.text()).split('\n')) {
    if (!line.trim()) continue;
    let j: { type: string; delta?: string; part?: Part; tool?: string; message?: string; usage?: { input_tokens?: number; output_tokens?: number } };
    try { j = JSON.parse(line); } catch { continue; }
    if (j.type === 'text') ex.text += j.delta ?? '';
    else if (j.type === 'ui' && j.part) ex.parts.push(j.part);
    else if (j.type === 'status' && j.tool) ex.tools.push(j.tool);
    else if (j.type === 'error') ex.error = j.message;
    else if (j.type === 'done') { ex.inputTokens = j.usage?.input_tokens ?? 0; ex.outputTokens = j.usage?.output_tokens ?? 0; }
  }
  ex.text = ex.text.replace(/\s+/g, ' ').trim();
  return { conversationId: r.headers.get('x-conversation-id'), ex };
}

/** A PostgREST read as the eval user — how every assertion about stored rows is settled. */
async function rows<T = Record<string, unknown>>(s: Session, path: string): Promise<T[]> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { headers: { apikey: ANON!, authorization: `Bearer ${s.jwt}` } });
  if (!r.ok) throw new Error(`rest ${path} ${r.status}: ${await r.text()}`);
  return await r.json() as T[];
}
async function patch(s: Session, path: string, body: Record<string, unknown>): Promise<number> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { method: 'PATCH', headers: { apikey: ANON!, authorization: `Bearer ${s.jwt}`, 'content-type': 'application/json', prefer: 'return=representation' }, body: JSON.stringify(body) });
  if (!r.ok) throw new Error(`rest PATCH ${path} ${r.status}: ${await r.text()}`);
  return ((await r.json()) as unknown[]).length;
}

// ---------------------------------------------------------------- case scaffolding
interface CaseCtx {
  s: Session;
  /** Says something in a fresh or continuing conversation and returns the turn. */
  say: (text: string, o?: { kind?: 'general' | 'meal_planning'; conversationId?: string | null }) => Promise<{ conversationId: string | null; ex: Exchange }>;
  opener: (kind: 'general' | 'meal_planning') => Promise<{ conversationId: string | null; ex: Exchange }>;
  rows: typeof rows;
  patch: typeof patch;
  /** Records a failure; a case with none passes. */
  fail: (why: string) => void;
  log: (line: string) => void;
}
interface EvalCase { name: string; about: string; ticket: string; run: (c: CaseCtx) => Promise<void> }

const mentions = (t: string, ...words: string[]) => words.some((w) => new RegExp(`\\b${w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(t));
const DONT_KNOW = /\b(i (don'?t|do not) (know|have)|no (information|data|record)|can'?t (find|see|tell)|not sure|unable to)\b/i;

const CASES: EvalCase[] = [
  {
    name: 'knows-tomorrow', ticket: '03',
    about: 'General mode answers "what is my workout tomorrow" from the Doll, not from a tool that fails',
    async run(c) {
      const { ex } = await c.say("What's my workout tomorrow?", { kind: 'general' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      if (DONT_KNOW.test(ex.text)) c.fail(`answered that she does not know: "${ex.text}"`);
      const tomorrow = new Date(Date.now() + 86400_000).toISOString().slice(0, 10);
      const acts = await c.rows<{ title: string | null; activity_type: string }>(c.s, `activities?select=title,activity_type,scheduled_date_time&scheduled_date_time=gte.${tomorrow}&scheduled_date_time=lt.${tomorrow}T23:59:59&deleted_at=is.null`);
      c.log(`tomorrow's rows: ${acts.map((a) => a.title ?? a.activity_type).join(', ') || '(none)'}`);
      if (acts.length && !mentions(ex.text, ...acts.flatMap((a) => [a.title ?? '', a.activity_type]).filter(Boolean))) c.fail(`names none of tomorrow's sessions: "${ex.text}"`);
      if (!acts.length && !/\b(nothing|no (session|workout|training)|rest)\b/i.test(ex.text)) c.fail(`no session tomorrow, but the answer does not say so: "${ex.text}"`);
    },
  },
  {
    name: 'logged-today', ticket: '03',
    about: 'General mode answers "what did I log today" without a failing tool call',
    async run(c) {
      const { ex } = await c.say('What did I log today?', { kind: 'general' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      if (DONT_KNOW.test(ex.text)) c.fail(`answered that she does not know: "${ex.text}"`);
      const today = new Date().toISOString().slice(0, 10);
      const logs = await c.rows<{ carbs_g: number | null }>(c.s, `meal_logs?select=carbs_g,calories&log_date=eq.${today}&is_deleted=eq.false`);
      c.log(`${logs.length} meal log row(s) today`);
      if (!logs.length && !/\b(nothing|no meals?|haven'?t logged|not logged)\b/i.test(ex.text)) c.fail(`nothing logged today, but the answer does not say so: "${ex.text}"`);
    },
  },
  {
    name: 'empty-doll-opener', ticket: '03',
    about: 'A planning opener still reads sensibly when the Doll is thin',
    async run(c) {
      const { ex } = await c.opener('meal_planning');
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      if (!ex.text.trim()) c.fail('opener produced no text');
      if (/\bundefined\b|\bnull\b|\bNaN\b/.test(ex.text)) c.fail(`opener leaks a placeholder: "${ex.text}"`);
      if (ex.text.length > 700) c.fail(`opener is ${ex.text.length} characters — far past the voice contract`);
    },
  },
  {
    name: 'remember-sticks', ticket: '05',
    about: '"Remember X" writes exactly one Memory, and the next conversation uses it unprompted',
    async run(c) {
      const before = await c.rows<{ id: string }>(c.s, 'user_memories?select=id&is_deleted=eq.false');
      const { ex } = await c.say('Remember that Wednesdays are chaos — I never have time to cook.', { kind: 'general' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      await new Promise((r) => setTimeout(r, 2000)); // the write lands in the background task
      const after = await c.rows<{ id: string; fact: string; source: string | null }>(c.s, 'user_memories?select=id,fact,source&is_deleted=eq.false&order=last_confirmed_at.desc');
      const added = after.filter((m) => !before.some((b) => b.id === m.id));
      c.log(`${added.length} memory row(s) added: ${added.map((m) => m.fact).join(' | ') || '(none)'}`);
      if (added.length !== 1) c.fail(`expected exactly 1 new Memory, got ${added.length}`);
      if (added[0] && !mentions(added[0].fact, 'wednesday', 'wednesdays')) c.fail(`the Memory does not mention Wednesdays: "${added[0].fact}"`);

      const { ex: next } = await c.say('What should I plan for midweek dinners?', { kind: 'general' });
      if (!mentions(next.text, 'wednesday', 'wednesdays', 'chaos', 'busy', 'no time', 'quick')) c.fail(`the next conversation does not use the Memory: "${next.text}"`);
    },
  },
  {
    name: 'plan-detail-is-not-a-memory', ticket: '05',
    about: 'This week\'s plan detail is not a margin note — "I want 5 dinners this week" writes nothing',
    async run(c) {
      const before = await c.rows<{ id: string }>(c.s, 'user_memories?select=id&is_deleted=eq.false');
      const { ex } = await c.say('I want 5 dinners this week.', { kind: 'meal_planning' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      await new Promise((r) => setTimeout(r, 2000));
      const after = await c.rows<{ id: string; fact: string }>(c.s, 'user_memories?select=id,fact&is_deleted=eq.false');
      const added = after.filter((m) => !before.some((b) => b.id === m.id));
      if (added.length) c.fail(`wrote ${added.length} Memory row(s) for a plan detail: ${added.map((m) => m.fact).join(' | ')}`);
    },
  },
  {
    name: 'keyed-memory-not-reasked', ticket: '05',
    about: 'A keyed Memory (batch cooking) is honoured without being asked again',
    async run(c) {
      const settings = await c.rows<{ key: string; fact: string }>(c.s, 'user_memories?select=key,fact&kind=eq.setting&is_deleted=eq.false');
      if (!settings.some((s) => s.key === 'batch_cooking')) { c.log('batch_cooking was never chosen — choosing it first'); await c.say('I cook in batches on Sundays.', { kind: 'meal_planning' }); await new Promise((r) => setTimeout(r, 2000)); }
      const { ex } = await c.opener('meal_planning');
      if (/\bbatch/i.test(ex.text) && /\?/.test(ex.text)) c.fail(`asks about batch cooking again: "${ex.text}"`);
    },
  },
  {
    name: 'passing-fact-extracted', ticket: '06',
    about: 'A fact said in passing, never flagged, becomes a Memory the next conversation knows',
    async run(c) {
      const before = await c.rows<{ id: string }>(c.s, 'user_memories?select=id&is_deleted=eq.false');
      const first = await c.say('My partner is vegetarian, so dinners have to work for both of us. What should I cook this week?', { kind: 'general' });
      if (first.ex.error) c.fail(`stream error: ${first.ex.error}`);
      if (/\bremember(ed|ing)?\b/i.test(first.ex.text)) c.fail(`announces what she learned: "${first.ex.text}"`);
      if (first.ex.parts.some((p) => p.kind === 'memory_saved')) c.fail('an extracted Memory produced a card');

      // Extraction is lazy: it runs when the NEXT conversation opens.
      const second = await c.say('What should I make tonight?', { kind: 'general' });
      await new Promise((r) => setTimeout(r, 3000));
      const after = await c.rows<{ id: string; fact: string; kind: string }>(c.s, 'user_memories?select=id,fact,kind&is_deleted=eq.false&order=last_confirmed_at.desc');
      const added = after.filter((m) => !before.some((b) => b.id === m.id));
      c.log(`${added.length} row(s) added: ${added.map((m) => `${m.kind}: ${m.fact}`).join(' | ') || '(none)'}`);
      if (!added.some((m) => m.kind !== 'episode' && mentions(m.fact, 'vegetarian', 'partner'))) c.fail('no Memory records the partner being vegetarian');
      if (!added.some((m) => m.kind === 'episode')) c.fail('no episode Memory for the finished conversation');
      void second;
    },
  },
  {
    name: 'feedback-lands', ticket: '01',
    about: 'A complaint typed at Vana becomes a feedback row with negative sentiment about Vana',
    async run(c) {
      const said = 'You keep suggesting fish and I have told you I do not eat it.';
      const { conversationId, ex } = await c.say(said, { kind: 'general' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      await new Promise((r) => setTimeout(r, 2000));
      const fb = await c.rows<{ sentiment: string; about: string; message: string; conversation_id: string | null }>(c.s, 'user_feedback?select=sentiment,about,message,conversation_id&order=created_at.desc&limit=5');
      const hit = fb.find((f) => f.conversation_id === conversationId);
      if (!hit) { c.fail(`no feedback row for conversation ${conversationId}`); return; }
      c.log(`feedback row: ${hit.sentiment} / ${hit.about} / "${hit.message}"`);
      if (hit.sentiment !== 'negative') c.fail(`sentiment is "${hit.sentiment}", expected negative`);
      if (hit.about !== 'vana') c.fail(`about is "${hit.about}", expected vana`);
      if (!hit.message.trim()) c.fail('the feedback row carries no message');
      const sentences = (ex.text.match(/[^.!?]+[.!?]+(\s|$)|[^.!?]+$/g) ?? []).filter((x) => x.trim());
      if (sentences.length > 2) c.fail(`acknowledgement is ${sentences.length} sentences — one was asked for: "${ex.text}"`);
      if (ex.parts.some((p) => p.kind === 'choices')) c.fail('offered chips instead of stopping');
    },
  },
  {
    name: 'taste-is-not-feedback', ticket: '01',
    about: 'A taste comment is not product feedback and writes no row',
    async run(c) {
      const before = await c.rows<{ id: string }>(c.s, 'user_feedback?select=id');
      const { ex } = await c.say('Not those — show me other options.', { kind: 'meal_planning' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      await new Promise((r) => setTimeout(r, 2000));
      const after = await c.rows<{ id: string }>(c.s, 'user_feedback?select=id');
      if (after.length !== before.length) c.fail(`a taste comment wrote ${after.length - before.length} feedback row(s)`);
    },
  },
  {
    name: 'home-location', ticket: '07',
    about: '"I live in Birmingham" is stored as a Fact and the weather answers for Birmingham',
    async run(c) {
      await c.say('I live in Birmingham, Alabama.', { kind: 'general' });
      await new Promise((r) => setTimeout(r, 2000));
      const [user] = await c.rows<{ home_city: string | null; home_timezone: string | null }>(c.s, 'users?select=home_city,home_timezone&limit=1');
      c.log(`home_city=${user?.home_city ?? '(null)'} home_timezone=${user?.home_timezone ?? '(null)'}`);
      if (!user?.home_city) c.fail('home_city was not written to the user record');
      else if (!/birmingham/i.test(user.home_city)) c.fail(`home_city is "${user.home_city}"`);
      const { ex } = await c.say("What's the weather tomorrow?", { kind: 'general' });
      if (!mentions(ex.text, 'birmingham')) c.fail(`the weather answer does not name Birmingham: "${ex.text}"`);
    },
  },
];

// ---------------------------------------------------------------- run
if (args.has('list')) { for (const c of CASES) console.log(`${c.name.padEnd(28)} ticket ${c.ticket}  ${c.about}`); Deno.exit(0); }
const todo = CASES.filter((c) => !only || only.includes(c.name));
if (!todo.length) { console.error(`personalization: nothing matched --only (try --list)`); Deno.exit(2); }

const jwt = await signIn();
const userId = JSON.parse(atob(jwt.split('.')[1])).sub as string;
const s: Session = { jwt, userId };
console.log(`personalization eval · dev · user ${userId} · ${todo.length} case(s)\n`);

type Result = { name: string; ticket: string; failures: string[]; turns: number; inputTokens: number; outputTokens: number; ms: number; log: string[] };
const results: Result[] = [];

for (const kase of todo) {
  const failures: string[] = []; const log: string[] = [];
  let turns = 0; let inputTokens = 0; let outputTokens = 0;
  const started = Date.now();
  const account = (ex: Exchange) => { turns++; inputTokens += ex.inputTokens; outputTokens += ex.outputTokens; if (verbose) console.log(`    "${ex.text}"`); return ex; };
  const ctx: CaseCtx = {
    s, rows, patch,
    fail: (why) => failures.push(why),
    log: (l) => { log.push(l); if (verbose) console.log(`    · ${l}`); },
    say: async (text, o) => { const r = await chat(s, { message: text, kind: o?.kind ?? 'general', conversation_id: o?.conversationId ?? null }); account(r.ex); return r; },
    opener: async (kind) => { const r = await chat(s, { opener: true, kind }); account(r.ex); return r; },
  };
  console.log(`▶ ${kase.name} — ${kase.about}`);
  try { await kase.run(ctx); } catch (e) { failures.push(`threw: ${(e as Error).message}`); }
  const ms = Date.now() - started;
  results.push({ name: kase.name, ticket: kase.ticket, failures, turns, inputTokens, outputTokens, ms, log });
  console.log(`  ${failures.length ? '✗' : '✓'} ${kase.name} · ${turns} turn(s) · in=${inputTokens} out=${outputTokens} · ${(ms / 1000).toFixed(1)}s`);
  for (const f of failures) console.log(`      FAIL ${f}`);
}

console.log('\n──────────────── cost per case ────────────────');
console.log(`${'case'.padEnd(28)} ${'turns'.padStart(5)} ${'in'.padStart(8)} ${'out'.padStart(7)}`);
for (const r of results) console.log(`${r.name.padEnd(28)} ${String(r.turns).padStart(5)} ${String(r.inputTokens).padStart(8)} ${String(r.outputTokens).padStart(7)}`);
const failed = results.filter((r) => r.failures.length);
console.log(`\n${failed.length ? '✗' : '✓'} ${results.length - failed.length}/${results.length} cases passed · tokens in=${results.reduce((a, r) => a + r.inputTokens, 0)} out=${results.reduce((a, r) => a + r.outputTokens, 0)}`);
if (out) { Deno.writeTextFileSync(out, JSON.stringify({ ranAt: new Date().toISOString(), userId, results }, null, 2)); console.log(`results → ${out}`); }
Deno.exit(failed.length ? 1 : 0);
