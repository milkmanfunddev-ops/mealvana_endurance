/**
 * One real multi-turn call against dev vana-eval (eval-v2 ticket 02). Signs in as the dev login, snapshots that
 * account's own rows (the Eval athlete a dev import would make), starts a Run user from it, sends three turns,
 * ends it, and checks what came back. Exits non-zero on any failed check.
 *
 *   deno run -A scripts/vana-eval/run-users-check.ts
 *
 * Reads SUPABASE_URL and SUPABASE_ANON_KEY from .env.dev.local and the login from the Keychain item
 * `mealvana-dev-login` (scripts/sim-dev-login.sh). The account must be an admin.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { COPY_TABLES, orderColumn, ownerColumn } from '../../supabase/functions/vana-eval/copy.ts';

const env = Object.fromEntries((await Deno.readTextFile('.env.dev.local')).split('\n').filter((l) => l.includes('=')).map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).trim()]));
const url = env.SUPABASE_URL, anon = env.SUPABASE_ANON_KEY;
const keychain = async (...args: string[]) => new TextDecoder().decode((await new Deno.Command('security', { args: ['find-generic-password', '-s', 'mealvana-dev-login', ...args] }).output()).stdout);
const email = (await keychain()).match(/"acct"<blob>="([^"]+)"/)?.[1];
const password = (await keychain('-w')).trim();
if (!email || !password) throw new Error('no mealvana-dev-login Keychain item');

const sb = createClient(url, anon, { auth: { persistSession: false } });
const { data: login, error: loginError } = await sb.auth.signInWithPassword({ email, password });
if (loginError || !login.session) throw new Error(`sign-in failed: ${loginError?.message}`);
const me = login.user.id;
const fn = `${url}/functions/v1/vana-eval`;
const call = (body: unknown) => fetch(fn, { method: 'POST', headers: { Authorization: `Bearer ${login.session!.access_token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

let failed = 0;
const check = (ok: boolean, what: string) => { console.log(`${ok ? '✓' : '✗'} ${what}`); if (!ok) failed++; };

// The snapshot: the account's own rows, read through RLS as the account itself.
const tables: Record<string, unknown[]> = {};
for (const t of COPY_TABLES) {
  const { data, error } = await sb.from(t).select('*').eq(ownerColumn(t), me).order(orderColumn(t));
  if (error) throw new Error(`snapshot ${t}: ${error.message}`);
  if (data?.length) tables[t] = data;
}
const sourceBefore = JSON.stringify(tables);
console.log(`snapshot: ${Object.entries(tables).map(([t, r]) => `${t}=${r.length}`).join(' ')}`);

const started = await call({ action: 'start', snapshot: { user_id: me, tables } });
const startBody = await started.json();
check(started.status === 200, `start → ${started.status} ${started.status === 200 ? '' : JSON.stringify(startBody)}`);
if (started.status !== 200) Deno.exit(1);
const runUser = startBody.run_user_id as string;
check(runUser !== me, `Run user ${runUser} is not the source`);

let conversationId: string | undefined;
let toolResults = 0;
for (const message of ['What workouts do I have coming up this week?', 'What meals did I log over the last 3 days? Look it up.', 'Thanks, that helps.']) {
  const r = await call({ action: 'turn', run_user_id: runUser, conversation_id: conversationId, message, kind: 'general', timezone: 'America/Chicago' });
  const lines = (await r.text()).split('\n').filter(Boolean).map((l) => JSON.parse(l));
  const trace = lines.find((l) => l.type === 'trace');
  const reply = lines.filter((l) => l.type === 'text').map((l) => l.delta).join('');
  check(r.status === 200 && !!trace?.trace, `turn "${message}" → ${r.status}, ${trace?.trace?.steps?.length ?? 0} steps, persisted=${trace?.persisted}`);
  if (!trace?.trace) { console.log(lines); break; }
  if (conversationId) check(trace.conversation_id === conversationId, 'same conversation');
  conversationId = trace.conversation_id;
  // deno-lint-ignore no-explicit-any
  for (const s of trace.trace.steps as any[]) {
    // deno-lint-ignore no-explicit-any
    for (const res of s.toolResults as any[]) toolResults++, check(res.input !== undefined && res.output !== undefined, `  ${res.toolName}: input ${JSON.stringify(res.input).slice(0, 60)} → output ${JSON.stringify(res.output).length} chars`);
    check(typeof s.generationId === 'string' && s.generationId.startsWith('gen_'), `  step generation id ${s.generationId}`);
  }
  console.log(`  reply: ${reply.slice(0, 160).replace(/\n/g, ' ')}…`);
}

check(toolResults > 0, `the trace carries ${toolResults} tool result(s) with full input and output`);

const ended = await call({ action: 'end', run_user_id: runUser });
const endBody = await ended.json();
check(ended.status === 200 && !!endBody.before && !!endBody.after, `end → ${ended.status}`);
check((endBody.after?.tables?.vana_messages?.length ?? 0) >= 6, `after-snapshot holds the conversation (${endBody.after?.tables?.vana_messages?.length ?? 0} messages)`);
check((await call({ action: 'end', run_user_id: runUser })).status === 404, 'the Run user is gone');

const again: Record<string, unknown[]> = {};
for (const t of COPY_TABLES) { const { data } = await sb.from(t).select('*').eq(ownerColumn(t), me).order(orderColumn(t)); if (data?.length) again[t] = data; }
check(JSON.stringify(again) === sourceBefore, 'the source account is unchanged');

console.log(failed ? `${failed} check(s) failed` : 'all checks passed');
Deno.exit(failed ? 1 : 0);
