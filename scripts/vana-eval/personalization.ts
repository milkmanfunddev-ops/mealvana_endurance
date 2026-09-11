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

/** The dev service-role key, for the one case that needs a brand-new athlete. Env first, then the
 *  single copy the repo keeps in `secrets/supabase_service_role_keys.md` (its Dev Project block) —
 *  never duplicated into a second file. Absent → the case skips itself rather than failing. */
function devServiceRole(): string | null {
  const fromEnv = env('SUPABASE_SERVICE_ROLE_KEY'); if (fromEnv) return fromEnv;
  try {
    const md = Deno.readTextFileSync(root + 'secrets/supabase_service_role_keys.md');
    const dev = md.split(/^##\s+/m).find((s) => s.startsWith(`Dev Project (${DEV_REF})`));
    return dev?.match(/SUPABASE_SERVICE_ROLE_KEY=(\S+)/)?.[1] ?? null;
  } catch { return null; }
}
const SERVICE_ROLE = devServiceRole();

/** A brand-new dev athlete: an auth user plus the minimal `public.users` row the app would have
 *  after signup (no trigger does it). Returns a `close()` that deletes the user again, so dev does
 *  not accumulate eval junk and the case can be re-run. */
async function createThrowawayUser(): Promise<{ session: Session; close: () => Promise<void> }> {
  if (!SERVICE_ROLE) throw new Error('no dev service-role key (see secrets/supabase_service_role_keys.md)');
  const email = `vana-eval+first-${crypto.randomUUID().slice(0, 8)}@mealvana.test`;
  const password = `Eval-${crypto.randomUUID()}`;
  const admin = (path: string, init: RequestInit) => fetch(`${SUPABASE_URL}${path}`, { ...init, headers: { apikey: SERVICE_ROLE!, authorization: `Bearer ${SERVICE_ROLE}`, 'content-type': 'application/json', ...(init.headers ?? {}) } });
  const made = await admin('/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({ email, password, email_confirm: true }) });
  if (!made.ok) throw new Error(`admin create user ${made.status}: ${await made.text()}`);
  const userId = (await made.json()).id as string;
  const close = async () => { await admin(`/auth/v1/admin/users/${userId}`, { method: 'DELETE' }).catch(() => {}); };
  try {
    const row = await admin('/rest/v1/users', { method: 'POST', headers: { prefer: 'return=minimal' }, body: JSON.stringify({ id: userId, email, device_id: `vana-eval-${userId}`, auth_provider: 'email', is_anonymous: false, is_internal: true }) });
    if (!row.ok) throw new Error(`users row ${row.status}: ${await row.text()}`);
    const signed = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: ANON!, 'content-type': 'application/json' }, body: JSON.stringify({ email, password }) });
    if (!signed.ok) throw new Error(`sign-in ${signed.status}: ${await signed.text()}`);
    return { session: { jwt: (await signed.json()).access_token as string, userId }, close };
  } catch (e) { await close(); throw e; }
}

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
  /** A turn as somebody other than the eval user — the brand-new athlete of `feedback-prompt-once`. */
  as: (session: Session, body: Record<string, unknown>) => Promise<{ conversationId: string | null; ex: Exchange }>;
  rows: typeof rows;
  patch: typeof patch;
  /** Records a failure; a case with none passes. */
  fail: (why: string) => void;
  log: (line: string) => void;
}
interface EvalCase { name: string; about: string; ticket: string; run: (c: CaseCtx) => Promise<void> }

/** The `user_feedback` shape every feedback case reads back: sentiment and about live in the metadata jsonb; the column is `rating`. */
type FeedbackRow = { rating: number | null; message: string; conversation_id: string | null; metadata: { about?: string; sentiment?: string } | null };
const mentions = (t: string, ...words: string[]) => words.some((w) => new RegExp(`\\b${w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(t));
/** An opener that shows it knows the athlete by quoting the file rather than by using it. */
const READOUT = /\b(you told me|you mentioned|i remember|i recall|your notes|according to (my|your) notes|on file)\b/i;
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
      if (!acts.length && !/\b(nothing|no (session|workout|training)|rest|empty|anything)\b/i.test(ex.text)) c.fail(`no session tomorrow, but the answer does not say so: "${ex.text}"`);
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
      // A fact the eval user does not already have on file, so this tests the write rather than the dedupe.
      // (Wednesdays were the original fixture and are already a debrief pattern — the model correctly
      // declined to write them again, which is why this case was rewritten on 2026-09-10.)
      type Mem = { id: string; fact: string; kind: string; last_confirmed_at: string };
      const q = 'user_memories?select=id,fact,kind,last_confirmed_at&is_deleted=eq.false&order=last_confirmed_at.desc';
      const before = await c.rows<Mem>(c.s, q);
      const priorHit = before.find((m) => m.kind !== 'episode' && mentions(m.fact, 'broccoli')) ?? null;

      const { ex } = await c.say('Remember that I cannot stand the smell of cooked broccoli.', { kind: 'general' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      await new Promise((r) => setTimeout(r, 3000)); // the write lands in the background task
      const after = await c.rows<Mem>(c.s, q);
      const hit = after.find((m) => m.kind !== 'episode' && mentions(m.fact, 'broccoli')) ?? null;

      // "It sticks" is the contract, and it has two legal shapes: a new row on a first telling, or a
      // refreshed confirmed date when the note is already on file. Asserting only on insertion makes
      // the case pass once and fail on every re-run, which is a fault in the test, not the product.
      if (!hit) { c.fail('nothing on file mentions broccoli after asking Vana to remember it'); return; }
      if (!priorHit) {
        c.log(`new Memory written: "${hit.fact}"`);
        if (before.some((b) => b.id === hit.id)) c.fail('the row was already there — nothing was written');
      } else if (hit.last_confirmed_at > priorHit.last_confirmed_at) {
        c.log(`already on file; confirmed date refreshed ${priorHit.last_confirmed_at} → ${hit.last_confirmed_at}`);
      } else {
        c.fail(`already on file and NOT refreshed (${hit.last_confirmed_at}) — the remember tool did not fire`);
      }
      const extra = after.filter((m) => !before.some((b) => b.id === m.id) && m.kind !== 'episode');
      if (extra.length > 1) c.fail(`wrote ${extra.length} Memories for one request: ${extra.map((m) => m.fact).join(' | ')}`);

      const { ex: next } = await c.say('What should I make for dinner tonight?', { kind: 'general' });
      if (mentions(next.text, 'broccoli')) c.fail(`the next conversation suggests the thing they cannot stand: "${next.text}"`);
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
      // A question about batch cooking fails; an opener that honours it ("batch cooking is the move") and then asks
      // about dinners does not (openers name what they know since 2026-09-11, so "batch" and "?" now share a turn).
      const asked = ex.text.split(/(?<=[.!?])\s+/).filter((q) => q.endsWith('?') && /\bbatch/i.test(q));
      if (asked.length) c.fail(`asks about batch cooking again: "${asked.join(' ')}"`);
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
      // NOTE (2026-09-10): a card here means the model wrote the note itself mid-conversation rather than
      // the extractor writing it afterwards. Both are silent per the spec's intent, but the in-chat card is
      // an announcement the athlete did not ask for. Logged, not failed, until Lee rules on it.
      if (first.ex.parts.some((p) => p.kind === 'memory_saved')) c.log('a self-initiated rememberFact produced a card (open question)');

      // Extraction is lazy: conversation N is read back when conversation N+1 OPENS. A second `say`
      // continues nothing — it must be a NEW conversation, which is what `say` with no id gives us.
      //
      // The wait is for the rate limiter, not the model. `vana.extract` allows three read-backs a
      // minute, which is generous for a person and tight for an eval that opens a conversation every
      // few seconds. A rate-limited read-back RELEASES its claim, so nothing is lost — it just happens
      // on a later conversation, which is no use to an assertion made now.
      c.log('waiting out the extract rate-limit window before opening the next conversation');
      await new Promise((r) => setTimeout(r, 62_000));
      const second = await c.say('What should I make tonight?', { kind: 'general' });
      await new Promise((r) => setTimeout(r, 8000));
      const after = await c.rows<{ id: string; fact: string; kind: string }>(c.s, 'user_memories?select=id,fact,kind&is_deleted=eq.false&order=last_confirmed_at.desc');
      const added = after.filter((m) => !before.some((b) => b.id === m.id));
      c.log(`${added.length} row(s) added: ${added.map((m) => `${m.kind}: ${m.fact}`).join(' | ') || '(none)'}`);
      // Presence, not addition: on a re-run the fact is already on file and the deduped writer
      // correctly declines to write it twice. What matters is that Vana knows it.
      if (!after.some((m) => m.kind !== 'episode' && mentions(m.fact, 'vegetarian', 'partner'))) c.fail('no Memory records the partner being vegetarian');
      if (!added.some((m) => m.kind === 'episode')) c.fail('no episode Memory for the finished conversation');
      void second;
    },
  },
  {
    name: 'long-conversation-remembers-its-start', ticket: 'mealplanning 03',
    about: 'Past the 20-message history cap, Vana still knows something said in the first turn',
    async run(c) {
      // Something said once, at the very front, that no Fact or Memory would carry: who the ride is
      // with and how long it is. The filler turns never mention it, so by the last question the only
      // thing that can still carry it is the episode written when the cap first bit.
      const opening = "I'm riding four hours on Saturday with my friend Marco, and he's bringing a camping stove for a mid-ride stop. Help me plan the food.";
      // Everyday questions with no ride in them, so Vana has no reason to bring Saturday back up.
      const filler = [
        'What is a good everyday breakfast for someone who trains a lot?',
        'How much protein should I get at lunch?',
        'Is oatmeal or toast better on a normal workday?',
        'What is a quick weeknight dinner with lentils?',
        'Are frozen vegetables as good as fresh?',
        'How much coffee a day is too much?',
        'What is a good afternoon snack at my desk?',
        'Should I eat differently on a rest day?',
        'Is it fine to eat the same lunch every day?',
      ];
      const cap = 20;   // HISTORY_CAP in supabase/functions/_shared/vana/chat.ts
      type Msg = { role: string; content: string | null };
      type Ep = { id: string; fact: string };
      const episodes = (id: string) => c.rows<Ep>(c.s, `user_memories?select=id,fact&kind=eq.episode&key=eq.${id}&is_deleted=eq.false`);
      const stored = (id: string) => c.rows<Msg>(c.s, `vana_messages?select=role,content&conversation_id=eq.${id}&order=created_at`);

      const first = await c.say(opening, { kind: 'general' });
      const id = first.conversationId;
      if (!id) { c.fail('no conversation id came back'); return; }
      // Ten exchanges store twenty rows. The eleventh question is the twenty-first message: the cap bites.
      for (const q of filler) await c.say(q, { kind: 'general', conversationId: id });
      await new Promise((r) => setTimeout(r, 3000));
      const beforeCrossing = await stored(id);
      c.log(`${beforeCrossing.length} stored message(s) before the crossing turn`);
      if ((await episodes(id)).length) c.fail('an episode existed before the conversation crossed the cap');

      await c.say('What is a good snack before bed?', { kind: 'general', conversationId: id });
      await new Promise((r) => setTimeout(r, 8000));   // the episode is written in the background of that turn
      const written = await episodes(id);
      c.log(`episode after crossing: ${written.map((e) => `"${e.fact}"`).join(' | ') || '(none)'}`);
      if (written.length !== 1) { c.fail(`expected exactly one episode row after crossing the cap, found ${written.length}`); return; }

      const question = 'Remind me — who am I riding with on Saturday, and for how long?';
      // What the final turn replays besides the episode: the last cap-1 stored rows plus the question.
      // If a recent turn still carries the ride, the answer proves nothing about the episode.
      const replayWindow = (await stored(id)).slice(-(cap - 1));
      if (replayWindow.some((m) => mentions(m.content ?? '', 'Marco') || /\b(four|4)[- ]?hours?\b/i.test(m.content ?? ''))) {
        c.fail('inconclusive: a recent turn still mentions the ride, so this run cannot tell the episode from the replay window');
        return;
      }
      const { ex } = await c.say(question, { kind: 'general', conversationId: id });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      if (!mentions(ex.text, 'Marco')) c.fail(`forgot who the ride is with: "${ex.text}"`);
      if (!/\b(four|4)[- ]?(hours?|hrs?|h)\b/i.test(ex.text)) c.fail(`forgot how long the ride is: "${ex.text}"`);

      await new Promise((r) => setTimeout(r, 3000));
      const after = await episodes(id);
      if (after.length !== 1 || after[0].id !== written[0].id) c.fail(`later turns wrote another episode (${after.length} row(s))`);
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
      const fb = await c.rows<FeedbackRow>(c.s, 'user_feedback?select=rating,message,conversation_id,metadata,source&order=created_at.desc&limit=5');
      const hit = fb.find((f) => f.conversation_id === conversationId);
      if (!hit) { c.fail(`no feedback row for conversation ${conversationId}`); return; }
      c.log(`feedback row: rating ${hit.rating} / ${hit.metadata?.sentiment} / ${hit.metadata?.about} / "${hit.message}"`);
      if (hit.metadata?.sentiment !== 'negative') c.fail(`sentiment is "${hit.metadata?.sentiment}", expected negative`);
      if (hit.metadata?.about !== 'vana') c.fail(`about is "${hit.metadata?.about}", expected vana`);
      if (hit.rating !== -1) c.fail(`rating is ${hit.rating}, expected -1`);
      if (!hit.message.trim()) c.fail('the feedback row carries no message');
      // The acknowledgement is server-authored: the `feedback_saved` part IS the reply, drawn by the
      // client from `meal_planning.feedback_saved_row`. A pure complaint asks nothing, so Vana writes
      // no text at all — that is what stops the troubleshooting, and the sentence count was only ever
      // a proxy for it (ticket 01, 2026-09-10).
      if (!ex.parts.some((p) => p.kind === 'feedback_saved')) c.fail('no feedback_saved part — the athlete is shown nothing');
      if (ex.text.trim()) c.fail(`Vana wrote about the feedback herself; the app already says it is saved: "${ex.text}"`);
      if (ex.parts.some((p) => p.kind === 'choices')) c.fail('offered chips instead of stopping');
    },
  },
  {
    name: 'feedback-praise-lands', ticket: '01',
    about: 'Praise typed at Vana becomes a feedback row with positive sentiment about Vana',
    async run(c) {
      const said = 'The way you build my week around my long ride is genuinely the best thing about this app.';
      const { conversationId, ex } = await c.say(said, { kind: 'general' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      await new Promise((r) => setTimeout(r, 2000));
      const fb = await c.rows<FeedbackRow>(c.s, 'user_feedback?select=rating,message,conversation_id,metadata,source&order=created_at.desc&limit=5');
      const hit = fb.find((f) => f.conversation_id === conversationId);
      if (!hit) { c.fail(`no feedback row for conversation ${conversationId}`); return; }
      c.log(`feedback row: rating ${hit.rating} / ${hit.metadata?.sentiment} / ${hit.metadata?.about} / "${hit.message}"`);
      if (hit.metadata?.sentiment !== 'positive') c.fail(`sentiment is "${hit.metadata?.sentiment}", expected positive`);
      if (hit.rating !== 1) c.fail(`rating is ${hit.rating}, expected 1`);
      // about is logged, not asserted: praise that names "this app" while describing how Vana plans is genuinely
      // either vana or app, and the ticket asks only that praise land with positive sentiment.
      if (!hit.message.trim()) c.fail('the feedback row carries no message');
      if (!ex.parts.some((p) => p.kind === 'feedback_saved')) c.fail('no feedback_saved part — the athlete is shown nothing');
      if (ex.text.trim()) c.fail(`Vana wrote about the feedback herself: "${ex.text}"`);
    },
  },
  {
    name: 'feedback-suggestion-lands', ticket: '01',
    about: 'A wish for something that does not exist is filed as a suggestion, not a complaint',
    async run(c) {
      const said = 'I wish I could send the shopping list to my partner instead of only sharing it as text.';
      const { conversationId, ex } = await c.say(said, { kind: 'general' });
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      await new Promise((r) => setTimeout(r, 2000));
      const fb = await c.rows<FeedbackRow>(c.s, 'user_feedback?select=rating,message,conversation_id,metadata,source&order=created_at.desc&limit=5');
      const hit = fb.find((f) => f.conversation_id === conversationId);
      if (!hit) { c.fail(`no feedback row for conversation ${conversationId}`); return; }
      c.log(`feedback row: rating ${hit.rating} / ${hit.metadata?.sentiment} / ${hit.metadata?.about} / "${hit.message}"`);
      if (hit.metadata?.about !== 'suggestion') c.fail(`about is "${hit.metadata?.about}", expected suggestion`);
      if (!hit.message.trim()) c.fail('the feedback row carries no message');
      if (!ex.parts.some((p) => p.kind === 'feedback_saved')) c.fail('no feedback_saved part — the athlete is shown nothing');
    },
  },
  {
    name: 'feedback-prompt-once', ticket: '01',
    about: "A brand-new athlete's FIRST conversation carries the feedback prompt; their second does not",
    async run(c) {
      // The eval user has hundreds of conversations, so this path can only be exercised by a
      // brand-new athlete. The user is created and deleted here; nothing is left behind on dev.
      let made: { session: Session; close: () => Promise<void> };
      try { made = await createThrowawayUser(); } catch (e) { c.fail(`could not mint a brand-new athlete: ${(e as Error).message}`); return; }
      c.log(`brand-new athlete ${made.session.userId}`);
      try {
        const first = await c.as(made.session, { opener: true, kind: 'general' });
        if (first.ex.error) c.fail(`stream error on the first conversation: ${first.ex.error}`);
        if (!first.ex.parts.some((p) => p.kind === 'feedback_prompt')) c.fail(`the first conversation carries no feedback_prompt part (parts: ${first.ex.parts.map((p) => p.kind).join(', ') || 'none'})`);
        // A second conversation: no conversation_id, so the server opens a fresh one — and this
        // athlete now has a prior conversation, so the prompt must not come back.
        const second = await c.as(made.session, { opener: true, kind: 'general' });
        if (second.ex.error) c.fail(`stream error on the second conversation: ${second.ex.error}`);
        if (second.conversationId && second.conversationId === first.conversationId) c.fail('the second opener reused the first conversation — the once-only rule was never tested');
        if (second.ex.parts.some((p) => p.kind === 'feedback_prompt')) c.fail('the second conversation showed the feedback prompt again');
      } finally { await made.close(); c.log('brand-new athlete deleted'); }
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
  {
    name: 'opener-picks-up-last-talk', ticket: 'openers',
    about: 'The general opener picks up where the conversation before it left off, without reading notes aloud',
    async run(c) {
      const first = await c.say("I'm riding four hours on Saturday with Marco, and he's bringing a camping stove for oatmeal at the halfway stop. What should I eat Friday night?", { kind: 'general' });
      if (first.ex.error) c.fail(`stream error: ${first.ex.error}`);
      // The read-back runs when the next conversation opens; wait out vana.extract's per-minute limit first.
      c.log('waiting out the extract rate-limit window before the opener');
      await new Promise((r) => setTimeout(r, 62_000));
      const { ex } = await c.opener('general');
      const said = `${ex.text} ${JSON.stringify(ex.parts)}`;
      c.log(`opener: ${ex.text}`);
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      if (!mentions(said, 'Marco', 'stove', 'Saturday', 'ride', 'oatmeal')) c.fail(`the opener does not pick up the last conversation: "${ex.text}"`);
      if (READOUT.test(ex.text)) c.fail(`the opener reads its notes aloud: "${ex.text}"`);
    },
  },
  {
    name: 'plan-opener-is-theirs', ticket: 'openers',
    about: 'The planning opener carries something only this athlete has said, without reading notes aloud',
    async run(c) {
      const notes = await c.rows<{ fact: string; kind: string }>(c.s, 'user_memories?select=fact,kind&is_deleted=eq.false&order=last_confirmed_at.desc&limit=40');
      const { ex } = await c.opener('meal_planning');
      const said = `${ex.text} ${JSON.stringify(ex.parts)}`;
      c.log(`opener: ${ex.text}`);
      c.log(`on file: ${notes.filter((n) => n.kind !== 'episode').map((n) => n.fact).join(' | ') || '(no notes)'}`);
      if (ex.error) c.fail(`stream error: ${ex.error}`);
      if (!mentions(said, 'Marco', 'stove', 'Saturday', 'vegetarian', 'partner', 'broccoli', 'batch', 'Wednesday', 'late shift', 'variety')) c.fail(`the planning opener carries nothing personal: "${ex.text}"`);
      if (READOUT.test(ex.text)) c.fail(`the opener reads its notes aloud: "${ex.text}"`);
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
    as: async (session, body) => { const r = await chat(session, body); account(r.ex); return r; },
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
