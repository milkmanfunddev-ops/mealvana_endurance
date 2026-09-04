#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write --allow-env
/**
 * vana-eval — replays canned planning conversations against the dev `vana-chat` edge function and asserts the
 * Phase 1 voice contract (docs/new_mealplanning/vana-chatbot-update-plan.md §3.1 + §5 Phase 1 item 7):
 *   • no emoji anywhere · no narration ("Let me…") · no turn beyond the runaway guard
 *   • PICKING turns ≤2 sentences and naming a training fact · PRESENTING (opener) 2–4 sentences with a concrete athlete fact
 *   • every fork ≤4 options, each carrying a trade-off detail · EXPLAINING turns explain and recommend
 *   • MILESTONE sentence after confirm (≤1 exclamation mark, only there)
 *
 * This BILLS real model spend (Haiku, ~10 conversations × 2–5 turns) and writes real rows for the eval user
 * (conversations, a draft plan per conversation, and — for the `confirm` turn — a confirmed plan for the week).
 * Never wire it into CI or the test runner; run it by hand before shipping a persona change.
 *
 * Usage:
 *   deno run -A scripts/vana-eval/run.ts                    # every conversation
 *   deno run -A scripts/vana-eval/run.ts --only happy-path,why
 *   deno run -A scripts/vana-eval/run.ts --skip-confirm     # never send the confirm turn
 *   deno run -A scripts/vana-eval/run.ts --keep-settings    # don't reset batch_cooking / coverage_scope first (the forks then won't fire)
 *   deno run -A scripts/vana-eval/run.ts --verbose          # print every turn's text
 *   deno run -A scripts/vana-eval/run.ts --out transcript.json
 *
 * Credentials (env vars win; else read from the files): SUPABASE_URL + SUPABASE_ANON_KEY from `.env.dev.local`,
 * VANA_EVAL_EMAIL + VANA_EVAL_PASSWORD, falling back to INTEGRATION_TEST_EMAIL/PASSWORD from `secrets/integration_test.env`.
 * The eval user must be Pro (vana-chat is gated) — a 403 pro_required says so and exits 2.
 */

type Part = { kind: string; [k: string]: unknown };
type Turn = { say: string; expect?: string[]; confirm?: boolean; pick?: number };  // pick = tap the first N meals of the last picker via vana-action before speaking (what the app does on tap)
type Conversation = { name: string; about?: string; turns: Turn[] };
type Exchange = { role: 'opener' | 'user'; say?: string; text: string; parts: Part[]; status: string[]; error?: string; usage?: unknown };
type Check = (t: Exchange, ctx: { prev: Exchange | null; opener: Exchange; all: Exchange[] }) => string | null; // null = pass, string = failure reason

// ---------------------------------------------------------------- args + env
const args = new Map<string, string | true>();
for (let i = 0; i < Deno.args.length; i++) { const m = Deno.args[i].match(/^--([^=]+)(?:=(.*))?$/); if (!m) continue; const next = Deno.args[i + 1]; if (m[2] != null) args.set(m[1], m[2]); else if (next && !next.startsWith('--')) { args.set(m[1], next); i++; } else args.set(m[1], true); }
const verbose = args.has('verbose');
const skipConfirm = args.has('skip-confirm');
const keepSettings = args.has('keep-settings');
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
if (!SUPABASE_URL || !ANON || !EMAIL || !PASSWORD) { console.error('vana-eval: need SUPABASE_URL, SUPABASE_ANON_KEY, VANA_EVAL_EMAIL, VANA_EVAL_PASSWORD (see header)'); Deno.exit(2); }
if (!/vlmtsdzpnjnavdgytcmi/.test(SUPABASE_URL)) { console.error(`vana-eval: refusing to run against ${SUPABASE_URL} — dev only`); Deno.exit(2); }

// ---------------------------------------------------------------- transport
async function signIn(): Promise<string> {
  const r = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: ANON!, 'content-type': 'application/json' }, body: JSON.stringify({ email: EMAIL, password: PASSWORD }) });
  if (!r.ok) { console.error('vana-eval: sign-in failed', r.status, await r.text()); Deno.exit(2); }
  return (await r.json()).access_token as string;
}
async function chat(jwt: string, body: Record<string, unknown>): Promise<{ conversationId: string | null; ex: Exchange }> {
  const r = await fetch(`${SUPABASE_URL}/functions/v1/vana-chat`, { method: 'POST', headers: { apikey: ANON!, authorization: `Bearer ${jwt}`, 'content-type': 'application/json' }, body: JSON.stringify({ kind: 'meal_planning', timezone: Intl.DateTimeFormat().resolvedOptions().timeZone, ...body }) });
  if (r.status === 403) { console.error('vana-eval: 403 — the eval user is not Pro (pro_required)'); Deno.exit(2); }
  if (r.status === 429) { const j = await r.json().catch(() => ({})); const s = Number(j.retry_after_seconds ?? 10); console.log(`  rate limited — waiting ${s}s`); await new Promise((res) => setTimeout(res, s * 1000)); return chat(jwt, body); }
  if (!r.ok) throw new Error(`vana-chat ${r.status}: ${await r.text()}`);
  const ex: Exchange = { role: body.opener ? 'opener' : 'user', say: body.message as string | undefined, text: '', parts: [], status: [] };
  for (const line of (await r.text()).split('\n')) {
    if (!line.trim()) continue; let j: { type: string; delta?: string; part?: Part; tool?: string; message?: string; usage?: unknown };
    try { j = JSON.parse(line); } catch { continue; }
    if (j.type === 'text') ex.text += j.delta ?? ''; else if (j.type === 'ui' && j.part) ex.parts.push(j.part); else if (j.type === 'status' && j.tool) ex.status.push(j.tool); else if (j.type === 'error') ex.error = j.message; else if (j.type === 'done') ex.usage = j.usage;
  }
  ex.text = ex.text.replace(/\s+/g, ' ').trim();
  return { conversationId: r.headers.get('x-conversation-id'), ex };
}

/** The rule-4 forks only fire while a setting is "never chosen" — soft-delete the eval user's setting rows (same as forgetMemory) before every conversation so each starts there. */
async function resetSettings(jwt: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/user_memories?kind=eq.setting&key=in.(batch_cooking,coverage_scope)&is_deleted=eq.false`, { method: 'PATCH', headers: { apikey: ANON!, authorization: `Bearer ${jwt}`, 'content-type': 'application/json', prefer: 'return=representation' }, body: JSON.stringify({ is_deleted: true }) });
  if (!r.ok) throw new Error(`reset settings ${r.status}: ${await r.text()}`);
  console.log(`reset ${((await r.json()) as unknown[]).length} setting row(s) for the eval user`);
}

/** Tap meals the way the app does: `pick_meals` on vana-action, scoped to this conversation's draft. */
async function pickMeals(jwt: string, conversationId: string | null, prev: Exchange | null, n: number) {
  const p = prev ? picker(prev) : undefined; if (!p) { console.log('  – nothing to pick (no picker in the previous turn)'); return; }
  const meals = p.meals.slice(0, n).map((m) => ({ source: (m as { source?: string }).source ?? 'library', id: m.id }));
  const r = await fetch(`${SUPABASE_URL}/functions/v1/vana-action`, { method: 'POST', headers: { apikey: ANON!, authorization: `Bearer ${jwt}`, 'content-type': 'application/json' }, body: JSON.stringify({ type: 'pick_meals', payload: { meals, servings: 4, conversationId } }) });
  if (!r.ok) throw new Error(`pick_meals ${r.status}: ${await r.text()}`);
  console.log(`  · picked ${meals.length} meal(s) → plan`);
}

// ---------------------------------------------------------------- checks
const sentences = (t: string) => (t.match(/[^.!?]+[.!?]+(\s|$)|[^.!?]+$/g) ?? []).map((s) => s.trim()).filter(Boolean);
const EMOJI = /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F2FF}\u{FE0F}]/u;
const TRAINING_FACT = /\b(mon|tue|wed|thu|fri|sat|sun)(day|s|nesday|rsday|urday)?\b|\b(race|ride|run|swim|brick|interval|tempo|long|session|workout|threshold|hill|track|recovery|rest[- ]?(day|week)|\brest\b|easy week|taper|century|marathon|ironman|half|70\.3|10k|5k|training)\b|\b\d+\s?(d|days?|miles?|mi|km|min|minutes?|hours?|hrs?)\b/i;
const NARRATION = /^(let me|i'?ll (pull|check|look|grab|find)|i'?m (pulling|checking|looking|grabbing|finding)|now calling|one (sec|moment))/i;
const picker = (t: Exchange) => t.parts.find((p) => p.kind === 'meal_picker') as (Part & { mealType?: string; meals: { id: string; kind?: string }[] }) | undefined;
const choices = (t: Exchange) => t.parts.find((p) => p.kind === 'choices') as (Part & { options: string[]; details?: (string | null)[] }) | undefined;
const shownIds = (all: Exchange[]) => new Set(all.flatMap((e) => e.parts.filter((p) => p.kind === 'meal_picker' || p.kind === 'staples').flatMap((p) => ((p as { meals?: { id: string }[] }).meals ?? []).map((m) => m.id))));

/** Global checks — every turn, every conversation. */
const GLOBAL: Record<string, Check> = {
  no_error: (t) => (t.error ? `stream error: ${t.error}` : null),
  no_emoji: (t) => (EMOJI.test(t.text) ? `emoji in text: ${t.text}` : null),
  no_narration: (t) => (NARRATION.test(t.text) ? `narrates tool use: "${t.text.slice(0, 60)}"` : null),
  runaway: (t) => (sentences(t.text).length > 8 ? `${sentences(t.text).length} sentences (> 8 runaway guard)` : null),
  exclamation_policy: (t, { prev }) => { const n = (t.text.match(/!/g) ?? []).length; const milestone = t.parts.some((p) => p.kind === 'shopping_list' || p.kind === 'debrief'); if (n > 1) return `${n} exclamation marks (max 1, milestone only)`; if (n === 1 && !milestone) return `exclamation mark outside a MILESTONE turn`; void prev; return null; },
  forks_capped_with_details: (t) => { const c = choices(t); if (!c) return null; if (c.options.length > 4) return `${c.options.length} options (> 4)`; if (!c.details || c.details.length !== c.options.length || c.details.some((d) => !d)) return `fork without a trade-off detail per option: ${JSON.stringify(c)}`; return null; },
  picker_followed_by_text: (t) => (picker(t) && !t.text ? 'bare picker with no sentence' : null),
  no_askchoice_after_picker: (t) => (picker(t) && choices(t) ? 'askChoice after suggestMeals (chips are client-drawn)' : null),
};
/** Named checks — applied when a turn's `expect` lists them (and to the opener as `presenting`). */
const CHECKS: Record<string, Check> = {
  // The opener is the dietitian's opening question (2026-09-03, Lee): context first, ONE question with trade-off chips, no meals yet.
  presenting: (t) => { const n = sentences(t.text).length; if (n < 2 || n > 4) return `opener has ${n} sentences (2–3 expected)`; if (!TRAINING_FACT.test(t.text)) return `opener names no concrete athlete/training fact: "${t.text}"`; if (picker(t)) return 'opener proposed meals before asking'; const c = choices(t); if (!c) return 'opener asks no question (no choices part)'; if (!/\?/.test(t.text) && !c.question) return 'opener has no question'; return null; },
  first_picker: (t) => (picker(t) ? null : `expected the first dinner picker after the opener answer (parts: ${t.parts.map((p) => p.kind).join(',') || 'none'})`),
  picker: (t) => (picker(t) ? null : `no meal_picker (parts: ${t.parts.map((p) => p.kind).join(',') || 'none'})`),
  picking_brevity: (t) => { const n = sentences(t.text).length; return n > 2 ? `PICKING turn has ${n} sentences (> 2): "${t.text}"` : null; },
  training_fact: (t) => (TRAINING_FACT.test(t.text) ? null : `no training fact in why-line: "${t.text}"`),
  choices: (t) => (choices(t) ? null : `no choices part (parts: ${t.parts.map((p) => p.kind).join(',') || 'none'})`),
  fork_with_details: (t) => (choices(t) ? null : `expected a rule-4 fork (askChoice); got ${t.parts.map((p) => p.kind).join(',') || 'text only'}`),
  fork_or_picker: (t) => (choices(t) || picker(t) ? null : `expected the second fork or the next picker; got ${t.parts.map((p) => p.kind).join(',') || 'text only'}`),
  wrapup_or_picker: (t) => (picker(t) || (sentences(t.text).length >= 1 && !choices(t)) ? null : 'expected the wrap-up or a picker'),
  same_type_as_first: (t, { all }) => { const first = all.map(picker).find(Boolean); const a = picker(t)?.mealType; const b = first?.mealType; return a && b && a !== b ? `picker type ${a} ≠ first picker's ${b}` : null; },
  no_repeat: (t, { all }) => { const p = picker(t); if (!p) return null; const before = shownIds(all.slice(0, -1)); const dup = p.meals.filter((m) => before.has(m.id)).map((m) => m.id); return dup.length ? `repeats already-shown meals: ${dup.join(',')}` : null; },
  assemblies_only: (t) => { const p = picker(t); if (!p) return null; const bad = p.meals.filter((m) => m.kind !== 'assembly'); return bad.length ? `${bad.length} non-assembly meals in a "No recipe only" picker` : null; },
  explaining: (t) => { const n = sentences(t.text).length; return n < 2 ? `EXPLAINING turn has ${n} sentence(s): "${t.text}"` : null; },
  recommendation: (t) => (/my recommendation/i.test(t.text) && /(keep|revert)/i.test(t.text) ? null : `no "My recommendation … keep it or revert" beat: "${t.text}"`),
  no_weight_talk: (t) => (/\b(lose weight|weight loss|deficit|lean out|calorie cut|cutting)\b/i.test(t.text) ? `weight/cut framing: "${t.text}"` : null),
  wrapup: (t) => { const n = sentences(t.text).length; if (n < 1 || n > 4) return `wrap-up has ${n} sentences`; if (!/plan bar|review|confirm/i.test(t.text)) return `wrap-up does not point at review/confirm: "${t.text}"`; return null; },
  no_chips: (t) => (choices(t) ? 'chips after the wrap-up (should stop)' : null),
  milestone: (t) => { if (!t.parts.some((p) => p.kind === 'shopping_list')) return `confirm turn returned no shopping_list (parts: ${t.parts.map((p) => p.kind).join(',') || 'none'})`; if (!t.text) return 'no MILESTONE sentence after confirm'; if (!/\d|\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/i.test(t.text)) return `milestone names no count: "${t.text}"`; const c = choices(t); if (!c || c.options.length < 2 || c.options.length > 3) return 'expected ["Open shopping list", "Lay it across the week", "Adjust"] chips after confirm'; return null; },
  shopping_list: (t) => (t.parts.some((p) => p.kind === 'shopping_list') ? null : 'no shopping_list part'),
  referral: (t) => (/doctor or registered dietitian/i.test(t.text) ? null : `no medical referral line: "${t.text}"`),
  staples: (t) => (t.parts.some((p) => p.kind === 'staples') ? null : `no staples part (parts: ${t.parts.map((p) => p.kind).join(',') || 'none'})`),
  // ---- Phases 2, 7, 8
  batch: (t) => (t.parts.some((p) => p.kind === 'batch') ? null : `no batch part (parts: ${t.parts.map((p) => p.kind).join(',') || 'none'})`),
  presenting_turn: (t) => { const n = sentences(t.text).length; return n < 2 || n > 5 ? `PRESENTING turn has ${n} sentences (2–4 expected)` : null; },
  pantry: (t) => (t.parts.some((p) => p.kind === 'pantry') ? null : `no pantry part (parts: ${t.parts.map((p) => p.kind).join(',') || 'none'})`),
  uses_on_hand: (t) => { const p = picker(t); if (!p) return null; const hit = p.meals.some((m) => /uses your/i.test(String((m as { why?: string }).why ?? ''))); return hit ? null : 'no picker option names an on-hand ingredient in its why-line'; },
  week: (t) => (t.parts.some((p) => p.kind === 'week') ? null : `no week part (parts: ${t.parts.map((p) => p.kind).join(',') || 'none'})`),
};

// ---------------------------------------------------------------- run
const spec = JSON.parse(Deno.readTextFileSync(new URL('./conversations.json', import.meta.url))) as { conversations: Conversation[] };
const todo = spec.conversations.filter((c) => !only || only.includes(c.name));
if (!todo.length) { console.error('vana-eval: nothing matched --only'); Deno.exit(2); }
const jwt = await signIn();
let failures = 0; let turns = 0; let inTok = 0; let outTok = 0;
type Scored = Exchange & { results: Record<string, string | null> };
const transcript: Record<string, { conversationId: string | null; exchanges: Scored[] }> = {};
const resolveSay = (say: string, prev: Exchange | null): string => {
  const m = say.match(/^\$choice:(.+?)(?:\|(\d+))?$/); if (!m) return say;  // $choice:N · $choice:<label> · $choice:<label>|N (label if the fork has it, else option N)
  const c = prev ? choices(prev) : undefined; if (!c) return /^\d+$/.test(m[1]) ? 'I like these' : m[1];
  if (/^\d+$/.test(m[1])) return c.options[Number(m[1])] ?? c.options[0];
  const byLabel = c.options.find((o) => o.toLowerCase() === m[1].toLowerCase()) ?? c.options.find((o) => o.toLowerCase().includes(m[1].toLowerCase().split(' ')[0]));
  return byLabel ?? (m[2] != null ? c.options[Number(m[2])] ?? c.options[0] : m[1]);
};
const show = (label: string, ex: Exchange, results: Record<string, string | null>) => {
  const fails = Object.entries(results).filter(([, v]) => v);
  console.log(`  ${fails.length ? '✗' : '✓'} ${label}${ex.say ? ` ← "${ex.say}"` : ''}  [${ex.parts.map((p) => p.kind).join(',') || 'text'}]${ex.status.length ? ` tools=${ex.status.join(',')}` : ''}`);
  if (verbose || fails.length) console.log(`      "${ex.text}"`);
  for (const [k, v] of fails) console.log(`      FAIL ${k}: ${v}`);
};
for (const conv of todo) {
  console.log(`\n▶ ${conv.name}${conv.about ? ` — ${conv.about}` : ''}`);
  if (!keepSettings) await resetSettings(jwt); // per conversation — the previous one may have chosen a setting
  const all: Exchange[] = [];
  const { conversationId, ex: opener } = await chat(jwt, { opener: true });
  all.push(opener);
  const run = (ex: Exchange, expect: string[]) => { const ctx = { prev: all.length > 1 ? all[all.length - 2] : null, opener, all }; const results: Record<string, string | null> = {}; for (const [k, f] of Object.entries(GLOBAL)) results[k] = f(ex, ctx); for (const k of expect) results[k] = CHECKS[k] ? CHECKS[k](ex, ctx) : `unknown check ${k}`; const u = ex.usage as { input_tokens?: number; output_tokens?: number } | undefined; inTok += u?.input_tokens ?? 0; outTok += u?.output_tokens ?? 0; turns++; if (Object.values(results).some(Boolean)) failures++; return results; };
  const rec: { conversationId: string | null; exchanges: Scored[] } = { conversationId, exchanges: [] }; transcript[conv.name] = rec;
  rec.exchanges.push({ ...opener, results: (() => { const r = run(opener, ['presenting']); show('opener', opener, r); return r; })() });
  for (const t of conv.turns) {
    if (t.confirm && skipConfirm) { console.log('  – skipped confirm turn (--skip-confirm)'); continue; }
    if (t.pick) await pickMeals(jwt, conversationId, all[all.length - 1], t.pick);
    const say = resolveSay(t.say, all[all.length - 1]);
    const { ex } = await chat(jwt, { message: say, conversation_id: conversationId });
    all.push(ex);
    const r = run(ex, t.expect ?? []); show('turn', ex, r); rec.exchanges.push({ ...ex, results: r });
  }
}
console.log(`\n${failures ? '✗' : '✓'} ${turns} turns, ${failures} with failures · tokens in=${inTok} out=${outTok}`);
if (out) { Deno.writeTextFileSync(out, JSON.stringify(transcript, null, 2)); console.log(`transcript → ${out}`); }
Deno.exit(failures ? 1 : 0);
