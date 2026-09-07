#!/usr/bin/env -S deno run --allow-net --allow-read --allow-env
/**
 * vana-eval lifecycle — the relationship loop end to end against DEV (plan Phase 3.6, the server half of the Patrol flow):
 *   1. new conversation → pick 2 dinners → confirm the plan (vana-action)
 *   2. give one meal a `fresh-fri` session so a cook session lands today/tomorrow → a NEW conversation must open with the CHECK-IN
 *      (askChoice Ready / Swap something / Push it back) and stamp checkin_done_at
 *   3. time-travel: move that confirmed plan back one week (PATCH meal_plans.week_start as the user) → a NEW conversation must open
 *      with the DEBRIEF question → answer → recordDebrief lands (a `debrief` part, plan_debriefs row, debrief_done_at) → the next
 *      turn is this week's dinner picker and the context's LAST WEEK line feeds the proposal
 * Bills real Haiku spend (~4 turns) and writes rows for the eval user. Dev only. Same credentials as run.ts.
 *
 *   deno run -A scripts/vana-eval/lifecycle.ts [--verbose]
 */
type Part = { kind: string; [k: string]: unknown };
type Exchange = { text: string; parts: Part[]; status: string[]; error?: string };

const verbose = Deno.args.includes('--verbose');
function readEnvFile(path: string): Record<string, string> { try { const o: Record<string, string> = {}; for (const line of Deno.readTextFileSync(path).split('\n')) { const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/); if (m) o[m[1]] = m[2].replace(/^["']|["']$/g, ''); } return o; } catch { return {}; } }
const root = new URL('../../', import.meta.url).pathname;
const fileEnv = { ...readEnvFile(root + '.env.dev.local'), ...readEnvFile(root + 'secrets/integration_test.env') };
const env = (k: string, ...fb: string[]) => { for (const key of [k, ...fb]) { const v = Deno.env.get(key) ?? fileEnv[key]; if (v) return v; } return null; };
const URL_ = env('SUPABASE_URL')!; const ANON = env('SUPABASE_ANON_KEY')!; const EMAIL = env('VANA_EVAL_EMAIL', 'INTEGRATION_TEST_EMAIL')!; const PASSWORD = env('VANA_EVAL_PASSWORD', 'INTEGRATION_TEST_PASSWORD')!;
if (!URL_ || !ANON || !EMAIL || !PASSWORD) { console.error('need SUPABASE_URL, SUPABASE_ANON_KEY, VANA_EVAL_EMAIL, VANA_EVAL_PASSWORD'); Deno.exit(2); }
if (!/vlmtsdzpnjnavdgytcmi/.test(URL_)) { console.error('dev only'); Deno.exit(2); }

const r0 = await fetch(`${URL_}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: ANON, 'content-type': 'application/json' }, body: JSON.stringify({ email: EMAIL, password: PASSWORD }) });
if (!r0.ok) { console.error('sign-in failed', r0.status, await r0.text()); Deno.exit(2); }
const jwt = (await r0.json()).access_token as string;
const H = { apikey: ANON, authorization: `Bearer ${jwt}`, 'content-type': 'application/json' };
const rest = async (path: string, init: RequestInit) => { const r = await fetch(`${URL_}/rest/v1/${path}`, { ...init, headers: { ...H, prefer: 'return=representation', ...(init.headers ?? {}) } }); if (!r.ok) throw new Error(`${path} ${r.status}: ${await r.text()}`); return r.json(); };
const action = async (type: string, payload: Record<string, unknown>) => { const r = await fetch(`${URL_}/functions/v1/vana-action`, { method: 'POST', headers: H, body: JSON.stringify({ type, payload }) }); if (!r.ok) throw new Error(`${type} ${r.status}: ${await r.text()}`); return r.json() as Promise<{ parts: Part[] } & Record<string, unknown>>; };
async function chat(body: Record<string, unknown>): Promise<{ conversationId: string | null; ex: Exchange }> {
  const r = await fetch(`${URL_}/functions/v1/vana-chat`, { method: 'POST', headers: H, body: JSON.stringify({ kind: 'meal_planning', timezone: 'UTC', ...body }) });
  if (r.status === 429) { await new Promise((res) => setTimeout(res, 10_000)); return chat(body); }
  if (!r.ok) throw new Error(`vana-chat ${r.status}: ${await r.text()}`);
  const ex: Exchange = { text: '', parts: [], status: [] };
  for (const line of (await r.text()).split('\n')) { if (!line.trim()) continue; try { const j = JSON.parse(line); if (j.type === 'text') ex.text += j.delta ?? ''; else if (j.type === 'ui') ex.parts.push(j.part); else if (j.type === 'status') ex.status.push(j.tool); else if (j.type === 'error') ex.error = j.message; } catch { /* skip */ } }
  ex.text = ex.text.replace(/\s+/g, ' ').trim();
  return { conversationId: r.headers.get('x-conversation-id'), ex };
}
const choices = (ex: Exchange) => ex.parts.find((p) => p.kind === 'choices') as (Part & { options: string[] }) | undefined;
let failures = 0;
const check = (label: string, ok: boolean, detail = '') => { console.log(`  ${ok ? '✓' : '✗'} ${label}${!ok && detail ? ` — ${detail}` : ''}`); if (!ok) failures++; };
const show = (ex: Exchange) => { if (verbose || ex.error) console.log(`      "${ex.text}" [${ex.parts.map((p) => p.kind).join(',')}]${ex.error ? ` ERROR ${ex.error}` : ''}`); };
const todayIso = new Date().toISOString().slice(0, 10);
const addDays = (iso: string, n: number) => new Date(new Date(iso + 'T00:00:00Z').getTime() + n * 86400_000).toISOString().slice(0, 10);
const weekStartFor = (iso: string) => addDays(iso, -new Date(iso + 'T00:00:00Z').getUTCDay());

// ---- 0. clean slate: soft-delete settings; park any earlier plans of the eval user's last week so the time-travel PATCH cannot collide
await rest('user_memories?kind=eq.setting&key=in.(batch_cooking,coverage_scope)&is_deleted=eq.false', { method: 'PATCH', body: JSON.stringify({ is_deleted: true }) });
const ws = weekStartFor(todayIso); const lastWs = addDays(ws, -7);
const parked = await rest(`meal_plans?week_start=eq.${lastWs}`, { method: 'PATCH', body: JSON.stringify({ week_start: '2020-01-0' + (1 + Math.floor(Math.random() * 9)), status: 'archived', updated_at: new Date().toISOString() }) });
// any confirmed plan of THIS week would also block a second confirm (one confirmed per week) → archive it
const archived = await rest(`meal_plans?week_start=eq.${ws}&status=eq.confirmed`, { method: 'PATCH', body: JSON.stringify({ status: 'archived', updated_at: new Date().toISOString() }) });
console.log(`prepared: parked ${(parked as unknown[]).length} last-week plan(s), archived ${(archived as unknown[]).length} confirmed plan(s) this week`);

// ---- 1. build + confirm
console.log('\n▶ 1. build and confirm a plan');
const { conversationId, ex: opener } = await chat({ opener: true }); show(opener);
check('opener asks the opening question (choices, no meals yet)', !!choices(opener) && !opener.parts.some((p) => p.kind === 'meal_picker'));
const { ex: firstPick } = await chat({ message: choices(opener)?.options[0] ?? 'Batch-cook staples', conversation_id: conversationId }); show(firstPick);
const picker = firstPick.parts.find((p) => p.kind === 'meal_picker') as (Part & { meals: { source: string; id: string }[] }) | undefined;
check('the answer brings the first dinner picker', !!picker);
await action('pick_meals', { meals: (picker?.meals ?? []).slice(0, 2).map((m) => ({ source: m.source, id: m.id })), servings: 4, conversationId });
const confirmed = await action('confirm_plan', { conversationId });
const plan = (confirmed.parts.find((p) => p.kind === 'batch') as (Part & { plan: { id: string; status: string; meals: { id: string; session: string | null }[] } }) | undefined)?.plan;
check('confirm_plan returns a confirmed batch with meals', plan?.status === 'confirmed' && (plan?.meals.length ?? 0) >= 2, JSON.stringify(plan?.status));
if (!plan) Deno.exit(1);

// ---- 2. check-in opener: force a cook session onto today/tomorrow
console.log('\n▶ 2. check-in opener');
const sessionFor = (date: string) => ({ [ws]: 'cook-sun', [addDays(ws, 3)]: 'topup-wed', [addDays(ws, 5)]: 'fresh-fri' } as Record<string, string>)[date];
const target = sessionFor(todayIso) ?? sessionFor(addDays(todayIso, 1));
if (!target) console.log(`  – no session date falls on today/tomorrow (today ${todayIso}, week ${ws}) — check-in cannot fire today; skipping step 2`);
else {
  await action('set_session', { planMealId: plan.meals[0].id, session: target });
  const { ex } = await chat({ opener: true }); show(ex);
  const c = choices(ex);
  check(`new conversation opens with the check-in (${target})`, !!c && c.options.some((o) => /ready/i.test(o)) && c.options.some((o) => /push/i.test(o)), `parts ${ex.parts.map((p) => p.kind).join(',')}: "${ex.text.slice(0, 120)}"`);
  check('check-in has no meal picker', !ex.parts.some((p) => p.kind === 'meal_picker'));
  const [row] = await rest(`meal_plans?id=eq.${plan.id}&select=checkin_done_at`, { method: 'GET' }) as { checkin_done_at: string | null }[];
  check('checkin_done_at stamped', !!row?.checkin_done_at);
  const { ex: again } = await chat({ opener: true }); show(again);
  check('a second new conversation does not repeat the check-in', !choices(again) || !choices(again)!.options.some((o) => /push/i.test(o)));
}

// ---- 3. debrief opener: move the confirmed plan back a week
console.log('\n▶ 3. debrief opener → recordDebrief → next week starts');
await rest(`meal_plans?id=eq.${plan.id}`, { method: 'PATCH', body: JSON.stringify({ week_start: lastWs, checkin_done_at: new Date().toISOString(), updated_at: new Date().toISOString() }) });
const { conversationId: c3, ex: d1 } = await chat({ opener: true }); show(d1);
const dc = choices(d1);
check('new conversation opens with the debrief question', !!dc && dc.options.some((o) => /all of them/i.test(o)) && !d1.parts.some((p) => p.kind === 'meal_picker'), `parts ${d1.parts.map((p) => p.kind).join(',')}: "${d1.text.slice(0, 140)}"`);
const answer = dc?.options.find((o) => /most/i.test(o)) ?? 'Most of them';
const { ex: d2 } = await chat({ message: answer, conversation_id: c3 }); show(d2);
let debrief = d2.parts.find((p) => p.kind === 'debrief');
if (!debrief) { const { ex: d3 } = await chat({ message: 'The Wednesday one slipped — late shift, no time to cook', conversation_id: c3 }); show(d3); debrief = d3.parts.find((p) => p.kind === 'debrief'); if (!debrief) { const { ex: d4 } = await chat({ message: 'That is all — let us plan this week', conversation_id: c3 }); show(d4); debrief = d4.parts.find((p) => p.kind === 'debrief'); } }
check('recordDebrief produced a debrief part', !!debrief, debrief ? '' : 'no debrief part within 3 turns');
const rows = await rest(`plan_debriefs?plan_id=eq.${plan.id}&select=completed,planned,skip_reason`, { method: 'GET' }) as { completed: number; planned: number }[];
check('plan_debriefs row written', rows.length >= 1 && rows[0].planned >= 2, JSON.stringify(rows));
const [stamp] = await rest(`meal_plans?id=eq.${plan.id}&select=debrief_done_at`, { method: 'GET' }) as { debrief_done_at: string | null }[];
check('debrief_done_at stamped', !!stamp?.debrief_done_at);
const { ex: next } = await chat({ message: "Let's plan this week", conversation_id: c3 }); show(next);
check('the conversation moves on to this week (a picker or a fork)', next.parts.some((p) => p.kind === 'meal_picker' || p.kind === 'choices' || p.kind === 'batch'), `parts ${next.parts.map((p) => p.kind).join(',')}`);
const { ex: fresh } = await chat({ opener: true }); show(fresh);
check('a further new conversation opens normally (no repeated debrief)', !!choices(fresh) && !choices(fresh)!.options.some((o) => /all of them/i.test(o)));

console.log(`\n${failures ? '✗' : '✓'} lifecycle: ${failures} failure(s)`);
Deno.exit(failures ? 1 : 0);
