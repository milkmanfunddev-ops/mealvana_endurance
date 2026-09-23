#!/usr/bin/env -S deno run --allow-net --allow-read --allow-env
/**
 * picker-chip-cost — the model calls and input tokens a scripted five-picker planning conversation costs on DEV, with the
 * picker chips sent the way the app sends them (ai-cost ticket 12, mp-464 / mp-477).
 *
 *   --mode before   every picker chip is a tapped message to `vana-chat`: what the app did up to ticket 12.
 *   --mode after    "Other options", "Under 20 min", "Next: <type>" and "I like these" go to `vana-action next_picker`
 *                   first; only a tap the server hands back (`toVana`) reaches `vana-chat`.
 *
 * The script: a throwaway Pro athlete with both rule-4 forks already settled (batch on, dinners and lunches), so the
 * only steps that are Vana's are the ones the ticket leaves her. Then: the new-plan opener → a typed "Quick weeknights"
 * (the first dinner picker, from Vana) → pick 2 → "Other options" → "Under 20 min" → pick 1 → "Next: Lunch" → pick 2
 * → "Other options" → pick 1 → "I like these" (the walk is spent: Vana wraps up). Five pickers, five chip taps.
 * The figures are read back from `vana_calls` for the conversation, so they are what the log records, not what the
 * script thinks it sent. The athlete is deleted at the end.
 *
 * Spend: in `before`, about seven Haiku turns on the DEV key; in `after`, about three.
 *
 * Credentials: SUPABASE_URL + SUPABASE_ANON_KEY from `.env.dev.local`; SUPABASE_SERVICE_ROLE_KEY (dev) from the
 * environment, to make and delete the throwaway athlete. Dev only, by project ref.
 *
 * Usage: SUPABASE_SERVICE_ROLE_KEY=… deno run -A scripts/vana-eval/picker-chip-cost.ts --mode before
 */
type Part = { kind: string; [k: string]: unknown };
type Picker = Part & { mealType?: string; meals: { id: string; source?: string }[] };

const args = new Map<string, string>();
for (let i = 0; i < Deno.args.length; i++) { const m = Deno.args[i].match(/^--([^=]+)(?:=(.*))?$/); if (!m) continue; const next = Deno.args[i + 1]; if (m[2] != null) args.set(m[1], m[2]); else if (next && !next.startsWith('--')) { args.set(m[1], next); i++; } else args.set(m[1], 'true'); }
const mode = args.get('mode');
if (mode !== 'before' && mode !== 'after') { console.error('picker-chip-cost: --mode before | after'); Deno.exit(2); }

function readEnvFile(path: string): Record<string, string> {
  try { const o: Record<string, string> = {}; for (const line of Deno.readTextFileSync(path).split('\n')) { const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/); if (m) o[m[1]] = m[2].replace(/^["']|["']$/g, ''); } return o; } catch { return {}; }
}
const root = new URL('../../', import.meta.url).pathname;
const fileEnv = readEnvFile(root + '.env.dev.local');
const env = (k: string) => Deno.env.get(k) ?? fileEnv[k] ?? null;
const SUPABASE_URL = env('SUPABASE_URL'); const ANON = env('SUPABASE_ANON_KEY'); const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? null;
const DEV_REF = 'vlmtsdzpnjnavdgytcmi';
if (!SUPABASE_URL || !ANON || !SERVICE) { console.error('picker-chip-cost: need SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY'); Deno.exit(2); }
if (!SUPABASE_URL.includes(DEV_REF)) { console.error(`picker-chip-cost: refusing to run against ${SUPABASE_URL} — dev (${DEV_REF}) only`); Deno.exit(2); }

const admin = (path: string, init: RequestInit = {}) => fetch(`${SUPABASE_URL}${path}`, { ...init, headers: { apikey: SERVICE!, authorization: `Bearer ${SERVICE}`, 'content-type': 'application/json', ...(init.headers ?? {}) } });

// ---------------------------------------------------------------- the throwaway athlete
const email = `vana-eval+chips-${crypto.randomUUID().slice(0, 8)}@mealvana.test`;
const password = `Eval-${crypto.randomUUID()}`;
const made = await admin('/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({ email, password, email_confirm: true }) });
if (!made.ok) { console.error('create user', made.status, await made.text()); Deno.exit(1); }
const userId = (await made.json()).id as string;
const close = async () => { if (args.has('cleanup')) await admin(`/auth/v1/admin/users/${userId}`, { method: 'DELETE' }).catch(() => {}); };

try {
  const must = async (r: Response, what: string) => { if (!r.ok) throw new Error(`${what} ${r.status}: ${await r.text()}`); return r; };
  await must(await admin('/rest/v1/users', { method: 'POST', headers: { prefer: 'return=minimal' }, body: JSON.stringify({ id: userId, email, first_name: 'Eval', device_id: `vana-eval-${userId}`, auth_provider: 'email', is_anonymous: false, is_internal: true }) }), 'users row');
  await must(await admin('/rest/v1/user_entitlements', { method: 'POST', headers: { prefer: 'return=minimal,resolution=merge-duplicates' }, body: JSON.stringify({ user_id: userId, period_type: 'P1M', active_until: new Date(Date.now() + 30 * 864e5).toISOString(), event_at: new Date().toISOString() }) }), 'entitlement');
  const signed = await must(await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: ANON, 'content-type': 'application/json' }, body: JSON.stringify({ email, password }) }), 'sign-in');
  const jwt = (await signed.json()).access_token as string;
  const user = { apikey: ANON, authorization: `Bearer ${jwt}`, 'content-type': 'application/json' };

  const action = async (type: string, payload: Record<string, unknown>) => (await must(await fetch(`${SUPABASE_URL}/functions/v1/vana-action`, { method: 'POST', headers: user, body: JSON.stringify({ type, payload }) }), `vana-action ${type}`)).json();
  let conversationId: string | null = null;
  const chat = async (body: Record<string, unknown>): Promise<Part[]> => {
    const r = await must(await fetch(`${SUPABASE_URL}/functions/v1/vana-chat`, { method: 'POST', headers: user, body: JSON.stringify({ kind: 'meal_planning', timezone: 'America/Chicago', ...(conversationId ? { conversation_id: conversationId } : {}), ...body }) }), 'vana-chat');
    conversationId ??= r.headers.get('x-conversation-id');
    const parts: Part[] = [];
    for (const line of (await r.text()).split('\n')) { try { const j = JSON.parse(line); if (j.type === 'ui' && j.part) parts.push(j.part); } catch { /* not a line */ } }
    return parts;
  };

  // Both forks settled the way the settings sheet settles them: no chip, so nothing is stored in a conversation.
  await action('set_setting', { key: 'batch_cooking', value: true });
  await action('set_setting', { key: 'coverage_scope', value: 'dinners_lunches' });

  let last: Picker | undefined;
  const pickers: string[] = [];
  const took = (parts: Part[], how: string) => { const p = parts.find((x) => x.kind === 'meal_picker') as Picker | undefined; if (p) { last = p; pickers.push(`${p.mealType} (${how})`); } console.log(`  ${how}: ${parts.map((x) => x.kind).join(',') || 'text only'}`); };
  const pick = async (n: number) => { if (!last) return; await action('pick_meals', { conversationId, meals: last.meals.slice(0, n).map((m) => ({ source: m.source ?? 'library', id: m.id })) }); };
  const tap = async (label: string, chipKind: string, mealType?: string) => {
    if (mode === 'after') {
      const r = await action('next_picker', { conversationId, chip: label, chipKind, ...(mealType ? { mealType } : {}) });
      if (!r.toVana) return took(r.parts as Part[], `"${label}" → vana-action`);
    }
    took(await chat({ message: label, input_mode: 'tap' }), `"${label}" → vana-chat`);
  };

  console.log(`▶ ${mode}: ${email}`);
  took(await chat({ opener: true, new_plan: true }), 'opener');
  took(await chat({ message: 'Quick weeknights', input_mode: 'typed' }), '"Quick weeknights" (typed)');
  await pick(2); await tap('Other options', 'more');
  await tap('Under 20 min', 'under_20');
  await pick(1); await tap('Next: Lunch', 'next', 'lunch');
  await pick(2); await tap('Other options', 'more');
  await pick(1); await tap('I like these', 'next');

  const rows = (await (await must(await admin(`/rest/v1/vana_calls?conversation_id=eq.${conversationId}&select=function_name,model,input_tokens,input_mode,debited,steps&order=created_at`), 'vana_calls')).json()) as { function_name: string; model: string; input_tokens: number; input_mode: string | null; debited: boolean; steps: number | null }[];
  const model = rows.filter((r) => r.model !== 'none');
  const taps = rows.filter((r) => r.model === 'none');
  console.log(`\nuser ${userId} · conversation ${conversationId}`);
  for (const r of rows) console.log(`  ${r.function_name.padEnd(40)} ${r.model.padEnd(28)} in=${String(r.input_tokens).padStart(6)} mode=${r.input_mode ?? '-'} debited=${r.debited}`);
  console.log(`\npickers shown: ${pickers.length} — ${pickers.join(' · ')}`);
  console.log(`model calls: ${model.length} · input tokens: ${model.reduce((s, r) => s + (r.input_tokens ?? 0), 0)} · taps with no model: ${taps.length}`);
} finally {
  await close();
}
