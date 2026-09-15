/**
 * Wallet rules for the monthly Allowance (mp-281, ticket 20), proved against
 * the real SQL functions on the DEV project — the rules live in Postgres
 * (supabase/migrations/20260916130000_monthly_allowance.sql), so a fake
 * would only test the fake.
 *
 * Every scenario runs inside one transaction that is ROLLED BACK: a throwaway
 * auth.users row, its wallet, ledger and entitlement row never persist. The
 * Management API's query endpoint returns the last statement with rows,
 * which is the assertions row selected just before the rollback.
 *
 * Skipped unless both are set (never in CI):
 *   SUPABASE_MANAGEMENT_TOKEN   — secrets/supabase_management_api.env
 *   WALLET_TEST_PROJECT_REF     — the DEV ref only (vlmtsdzpnjnavdgytcmi)
 *
 * Run with:
 *   WALLET_TEST_PROJECT_REF=vlmtsdzpnjnavdgytcmi SUPABASE_MANAGEMENT_TOKEN=… \
 *     deno test --allow-net --allow-env --allow-sys supabase/functions/_shared/ai/wallet_rules.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';

const TOKEN = Deno.env.get('SUPABASE_MANAGEMENT_TOKEN');
const REF = Deno.env.get('WALLET_TEST_PROJECT_REF');
const PROD_REF = 'wvmvsodrvbkxfydabqed';
const live = !!TOKEN && !!REF && REF !== PROD_REF;

const ALLOWANCE = 300;

async function runScenario(sql: string): Promise<Record<string, unknown>> {
  const res = await fetch(`https://api.supabase.com/v1/projects/${REF}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`query failed (${res.status}): ${JSON.stringify(body)}`);
  assert(Array.isArray(body) && body.length === 1, `expected one assertions row, got ${JSON.stringify(body)}`);
  return body[0].out as Record<string, unknown>;
}

/** Wrap the scenario body in a rolled-back transaction with a throwaway user. */
function scenario(body: string): string {
  return `
begin;
create temp table r(k text, v jsonb) on commit drop;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  values ('00000000-0000-4000-8000-00000000c020', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'wallet-rules-ticket-20@test.invalid', '', now(), now(), now(), '{}', '{}');
-- user_entitlements references public.users, not auth.users.
insert into public.users (id, device_id) values ('00000000-0000-4000-8000-00000000c020', 'wallet-rules-ticket-20');
do $body$
declare u uuid := '00000000-0000-4000-8000-00000000c020'; j jsonb;
begin
${body}
end $body$;
select jsonb_object_agg(k, v) as out from r;
rollback;`;
}

const record = (k: string, expr: string) => `insert into r values ('${k}', to_jsonb(${expr}));`;
const recordJson = (k: string, expr: string) => `insert into r values ('${k}', ${expr});`;
const wallet = (k: string) =>
  `insert into r values ('${k}', (select jsonb_build_object('balance', balance, 'allowance', allowance, 'monthly', allowance_monthly, 'expires', allowance_expires_at) from public.token_wallets where user_id = u));`;

Deno.test({
  name: 'wallet rules (live, DEV, rolled back) — the trial grant lands in full and the window is the trial end',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      j := public.grant_allowance(u, ${ALLOWANCE}, now() + interval '7 days', 'evt-trial');
      ${recordJson('grant', 'j')}
      ${wallet('wallet')}
      ${record('expires_is_trial_end', `(select allowance_expires_at between now() + interval '7 days' - interval '1 minute' and now() + interval '7 days' + interval '1 minute' from public.token_wallets where user_id = u)`)}
      ${record('ledger', `(select jsonb_agg(jsonb_build_object('reason', reason, 'delta', delta, 'ref', ref) order by created_at) from public.token_ledger where user_id = u)`)}
    `));
    const grant = out.grant as Record<string, unknown>;
    assertEquals(grant.granted, true);
    assertEquals(grant.forfeited, 0);
    const w = out.wallet as Record<string, unknown>;
    assertEquals(w.balance, ALLOWANCE);
    assertEquals(w.allowance, ALLOWANCE);
    assertEquals(w.monthly, ALLOWANCE);
    assertEquals(out.expires_is_trial_end, true);
    assertEquals(out.ledger, [{ reason: 'grant_allowance', delta: ALLOWANCE, ref: 'evt-trial' }]);
  },
});

Deno.test({
  name: 'wallet rules — debits take the allowance first, then pack credits',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      perform public.grant_allowance(u, ${ALLOWANCE}, now() + interval '30 days', 'evt-1');
      perform public.grant_credits(u, 50, 'grant_purchase', 'pack-1');
      ${wallet('after_pack')}
      j := public.debit_credits(u, 1, 'debit_usage', 'vana-chat');
      ${recordJson('debit_one', 'j')}
      -- Two allowance credits left beside the pack: the next debit of three
      -- spends both and one pack credit.
      update public.token_wallets set allowance = 2, balance = 52 where user_id = u;
      j := public.debit_credits(u, 3, 'debit_usage', 'describe-meal');
      ${recordJson('debit_across', 'j')}
      j := public.debit_credits(u, 1, 'debit_usage', 'ai-coach');
      ${recordJson('debit_pack_only', 'j')}
      update public.token_wallets set allowance = 0, balance = 0 where user_id = u;
      j := public.debit_credits(u, 1, 'debit_usage', 'ai-coach');
      ${recordJson('debit_empty', 'j')}
    `));
    assertEquals((out.after_pack as Record<string, unknown>).balance, ALLOWANCE + 50);
    assertEquals((out.after_pack as Record<string, unknown>).allowance, ALLOWANCE);
    const one = out.debit_one as Record<string, unknown>;
    assertEquals(one, { success: true, balance: ALLOWANCE + 49, allowance: ALLOWANCE - 1, from_allowance: 1 });
    const across = out.debit_across as Record<string, unknown>;
    assertEquals(across, { success: true, balance: 49, allowance: 0, from_allowance: 2 });
    const packOnly = out.debit_pack_only as Record<string, unknown>;
    assertEquals(packOnly, { success: true, balance: 48, allowance: 0, from_allowance: 0 });
    assertEquals(out.debit_empty, { success: false, balance: 0, allowance: 0 });
  },
});

Deno.test({
  name: 'wallet rules — a renewal forfeits what is left and grants in full; the same event twice grants once',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      perform public.grant_allowance(u, ${ALLOWANCE}, now() + interval '30 days', 'evt-1');
      perform public.grant_credits(u, 50, 'grant_purchase', 'pack-1');
      update public.token_wallets set allowance = 100, balance = 150 where user_id = u;
      j := public.grant_allowance(u, ${ALLOWANCE}, now() + interval '60 days', 'evt-2');
      ${recordJson('renewal', 'j')}
      ${wallet('after_renewal')}
      j := public.grant_allowance(u, ${ALLOWANCE}, now() + interval '60 days', 'evt-2');
      ${recordJson('again', 'j')}
      ${wallet('after_again')}
      ${record('forfeits', `(select jsonb_agg(delta) from public.token_ledger where user_id = u and reason = 'forfeit_allowance')`)}
    `));
    const renewal = out.renewal as Record<string, unknown>;
    assertEquals(renewal.granted, true);
    assertEquals(renewal.forfeited, 100);
    const w = out.after_renewal as Record<string, unknown>;
    assertEquals(w.balance, 50 + ALLOWANCE, 'the 100 unused did not roll over; the 50 pack credits stayed');
    assertEquals(w.allowance, ALLOWANCE);
    assertEquals((out.again as Record<string, unknown>).granted, false);
    assertEquals(out.after_again, out.after_renewal);
    assertEquals(out.forfeits, [-100]);
  },
});

Deno.test({
  name: 'wallet rules — an expired allowance is forfeited before a debit; EXPIRATION forfeits and leaves the packs',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      perform public.grant_allowance(u, ${ALLOWANCE}, now() + interval '7 days', 'evt-trial');
      perform public.grant_credits(u, 50, 'grant_purchase', 'pack-1');
      update public.token_wallets set allowance_expires_at = now() - interval '1 second' where user_id = u;
      j := public.debit_credits(u, 1, 'debit_usage', 'vana-chat');
      ${recordJson('debit_after_expiry', 'j')}
      -- A second trial, this time closed by the webhook's EXPIRATION.
      perform public.grant_allowance(u, ${ALLOWANCE}, now() + interval '7 days', 'evt-trial-2');
      j := public.forfeit_allowance(u, 'evt-expiration');
      ${recordJson('forfeit', 'j')}
      ${wallet('after_forfeit')}
      j := public.forfeit_allowance(u, 'evt-expiration');
      ${recordJson('forfeit_again', 'j')}
    `));
    assertEquals(out.debit_after_expiry, { success: true, balance: 49, allowance: 0, from_allowance: 0 });
    assertEquals(out.forfeit, { forfeited: ALLOWANCE, balance: 49, allowance: 0 });
    const w = out.after_forfeit as Record<string, unknown>;
    assertEquals(w.balance, 49, 'pack credits untouched');
    assertEquals(w.allowance, 0);
    assertEquals(out.forfeit_again, { forfeited: 0, balance: 49, allowance: 0 });
  },
});

Deno.test({
  name: 'wallet rules — annual plans roll monthly on the anniversary day through ensure_allowance',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      insert into public.user_entitlements (user_id, active_until, period_type, event_at)
        values (u, now() + interval '365 days', 'NORMAL', now());
      -- The webhook's INITIAL_PURCHASE: the window is one month, not one year.
      j := public.grant_allowance(u, ${ALLOWANCE}, now() + interval '365 days', 'evt-annual');
      ${record('first_window_is_a_month', `((j->>'allowance_expires_at')::timestamptz between now() + interval '27 days' and now() + interval '32 days')`)}
      -- Nothing to do while the window is open.
      j := public.ensure_allowance(u, ${ALLOWANCE});
      ${recordJson('ensure_open', 'j')}
      -- The window passes with 20 unused: the next call forfeits and grants the next window.
      update public.token_wallets set allowance = 20, balance = 20, allowance_expires_at = now() - interval '1 hour' where user_id = u;
      j := public.ensure_allowance(u, ${ALLOWANCE});
      ${recordJson('ensure_rolled', 'j')}
      ${record('rolled_window_is_a_month', `((j->>'allowance_expires_at')::timestamptz between now() + interval '27 days' and now() + interval '32 days')`)}
      j := public.ensure_allowance(u, ${ALLOWANCE});
      ${recordJson('ensure_again', 'j')}
      -- No entitlement: nothing is granted, an expired allowance still goes.
      delete from public.user_entitlements where user_id = u;
      update public.token_wallets set allowance = 5, balance = 5, allowance_expires_at = now() - interval '1 hour' where user_id = u;
      j := public.ensure_allowance(u, ${ALLOWANCE});
      ${recordJson('ensure_lapsed', 'j')}
      ${record('monthly_window', `(public.allowance_window_end(now() + interval '30 days', now()) = now() + interval '30 days')`)}
    `));
    assertEquals(out.first_window_is_a_month, true);
    const open = out.ensure_open as Record<string, unknown>;
    assertEquals(open.granted, false);
    assertEquals(open.allowance, ALLOWANCE);
    const rolled = out.ensure_rolled as Record<string, unknown>;
    assertEquals(rolled.granted, true);
    assertEquals(rolled.allowance, ALLOWANCE);
    assertEquals(rolled.balance, ALLOWANCE, 'the 20 unused did not roll over');
    assertEquals(rolled.allowance_monthly, ALLOWANCE);
    assertEquals(out.rolled_window_is_a_month, true);
    assertEquals((out.ensure_again as Record<string, unknown>).granted, false);
    const lapsed = out.ensure_lapsed as Record<string, unknown>;
    assertEquals(lapsed, { balance: 0, allowance: 0, allowance_monthly: ALLOWANCE, allowance_expires_at: null, granted: false });
    assertEquals(out.monthly_window, true);
  },
});
