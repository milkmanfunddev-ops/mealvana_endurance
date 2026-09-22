/**
 * Wallet rules for the monthly Allowance (mp-281, ticket 20) and the monthly
 * budget metered in real cost (mp-430, mp-436, ai-cost ticket 09), proved
 * against the real SQL functions on the DEV project — the rules live in
 * Postgres (supabase/migrations/20260916130000_monthly_allowance.sql and
 * 20260922120000_ai_budget_micro_dollars.sql), so a fake would only test the
 * fake. Since ticket 09 the wallet holds whole micro-dollars; the amounts in
 * these scenarios are wallet arithmetic, never a model's price.
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
declare u uuid := '00000000-0000-4000-8000-00000000c020'; j jsonb; rid uuid;
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

// ---------------------------------------------------------------------------
// The monthly budget (ai-cost ticket 09): reserve, settle, refund, floor,
// allowance before packs, and the one-time credit conversion.
// ---------------------------------------------------------------------------

const MONTH = 4_000_000;   // a month of budget, in micro-dollars: the SQL takes it as a parameter
const ESTIMATE = 15_000;   // a reservation for one call

const reservation = (k: string) =>
  `insert into r values ('${k}', (select jsonb_build_object('estimate', estimate, 'from_allowance', from_allowance, 'real_cost', real_cost, 'charged', charged, 'settled', settled_at is not null) from public.token_reservations where id = rid));`;

Deno.test({
  name: 'budget — a reservation takes the estimate, settle takes the real cost: under gives back, over takes more',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      perform public.grant_allowance(u, ${MONTH}, now() + interval '30 days', 'evt-1');
      j := public.ai_budget_reserve(u, 'vana-chat', ${ESTIMATE}, ${MONTH}, null, 'vana-chat');
      ${recordJson('reserve', 'j')}
      rid := (j->>'reservation_id')::uuid;
      ${wallet('after_reserve')}
      j := public.ai_budget_settle(rid, 9000);
      ${recordJson('settle_under', 'j')}
      ${wallet('after_under')}
      ${reservation('row_under')}
      j := public.ai_budget_settle(rid, 9000);
      ${recordJson('settle_twice', 'j')}
      j := public.ai_budget_reserve(u, 'vana-chat', ${ESTIMATE}, ${MONTH}, null, 'vana-chat');
      rid := (j->>'reservation_id')::uuid;
      j := public.ai_budget_settle(rid, 21000);
      ${recordJson('settle_over', 'j')}
      ${wallet('after_over')}
      -- One transaction shares one now(), so the ledger is read sorted, not in insert order.
      ${record('ledger', `(select jsonb_agg(jsonb_build_object('reason', reason, 'delta', delta) order by reason, delta) from public.token_ledger where user_id = u and reason <> 'grant_allowance')`)}
    `));
    const reserve = out.reserve as Record<string, unknown>;
    assertEquals(reserve.allowed, true);
    assertEquals((out.after_reserve as Record<string, unknown>).balance, MONTH - ESTIMATE);
    assertEquals((out.after_reserve as Record<string, unknown>).allowance, MONTH - ESTIMATE);
    const under = out.settle_under as Record<string, unknown>;
    assertEquals(under.settled, true);
    assertEquals(under.charged, 9000);
    assertEquals((out.after_under as Record<string, unknown>).balance, MONTH - 9000);
    assertEquals(out.row_under, { estimate: ESTIMATE, from_allowance: ESTIMATE, real_cost: 9000, charged: 9000, settled: true });
    assertEquals((out.settle_twice as Record<string, unknown>).settled, false, 'a settle is idempotent');
    assertEquals((out.settle_over as Record<string, unknown>).charged, 21000);
    assertEquals((out.after_over as Record<string, unknown>).balance, MONTH - 9000 - 21000);
    assertEquals(out.ledger, [
      { reason: 'reserve_usage', delta: -ESTIMATE }, { reason: 'reserve_usage', delta: -ESTIMATE },
      { reason: 'settle_usage', delta: -6000 }, { reason: 'settle_usage', delta: 6000 },
    ]);
  },
});

Deno.test({
  name: 'budget — two reservations where one fits: the second starts inside and takes what is left (row lock), the third is refused and writes nothing',
  ignore: !live,
  async fn() {
    // mp-436 clause 1: a call that starts inside the budget runs even when its estimate is more than what is
    // left. Only an empty wallet refuses.
    const out = await runScenario(scenario(`
      perform public.grant_allowance(u, ${ESTIMATE + 5000}, now() + interval '30 days', 'evt-1');
      j := public.ai_budget_reserve(u, 'vana-chat', ${ESTIMATE}, ${MONTH}, null, 'a');
      ${recordJson('first', 'j')}
      j := public.ai_budget_reserve(u, 'vana-chat', ${ESTIMATE}, ${MONTH}, null, 'b');
      ${recordJson('second', 'j')}
      ${record('second_estimate', `(select estimate from public.token_reservations where user_id = u and ref = 'b')`)}
      j := public.ai_budget_reserve(u, 'vana-chat', ${ESTIMATE}, ${MONTH}, null, 'c');
      ${recordJson('third', 'j')}
      ${record('reservations', '(select count(*) from public.token_reservations where user_id = u)')}
      ${record('ledger_rows', `(select count(*) from public.token_ledger where user_id = u and reason = 'reserve_usage')`)}
    `));
    assertEquals((out.first as Record<string, unknown>).allowed, true);
    const second = out.second as Record<string, unknown>;
    assertEquals(second.allowed, true, 'the wallet had 5,000 left, so the call starts inside the budget');
    assertEquals(second.balance, 0, 'it took what was left, not its whole estimate');
    assertEquals(out.second_estimate, 5000, 'the reservation records what was actually taken');
    const third = out.third as Record<string, unknown>;
    assertEquals(third.allowed, false);
    assertEquals(third.balance, 0, 'the refusal reports the wallet as the second reservation left it');
    assertEquals(out.reservations, 2);
    assertEquals(out.ledger_rows, 2);
  },
});

Deno.test({
  name: 'budget — a failed call settles at zero and gets its whole reservation back',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      perform public.grant_allowance(u, ${MONTH}, now() + interval '30 days', 'evt-1');
      j := public.ai_budget_reserve(u, 'describe-meal', ${ESTIMATE}, ${MONTH}, null, 'describe-meal');
      rid := (j->>'reservation_id')::uuid;
      j := public.ai_budget_settle(rid, 0);
      ${recordJson('refund', 'j')}
      ${wallet('after')}
      ${reservation('row')}
      ${record('refund_rows', `(select jsonb_agg(delta) from public.token_ledger where user_id = u and reason = 'refund_usage')`)}
    `));
    assertEquals((out.refund as Record<string, unknown>).charged, 0);
    assertEquals((out.after as Record<string, unknown>).balance, MONTH);
    assertEquals((out.after as Record<string, unknown>).allowance, MONTH);
    assertEquals(out.row, { estimate: ESTIMATE, from_allowance: ESTIMATE, real_cost: 0, charged: 0, settled: true });
    assertEquals(out.refund_rows, [ESTIMATE]);
  },
});

Deno.test({
  name: 'budget — a call that started inside the budget finishes over it; the wallet floors at zero and the next is refused',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      perform public.grant_allowance(u, ${ESTIMATE}, now() + interval '30 days', 'evt-1');
      j := public.ai_budget_reserve(u, 'vana-chat', ${ESTIMATE}, ${MONTH}, null, 'vana-chat');
      ${recordJson('reserve', 'j')}
      rid := (j->>'reservation_id')::uuid;
      j := public.ai_budget_settle(rid, ${ESTIMATE + 10_000});
      ${recordJson('settle', 'j')}
      ${wallet('after')}
      j := public.ai_budget_reserve(u, 'vana-chat', ${ESTIMATE}, ${MONTH}, null, 'vana-chat');
      ${recordJson('next', 'j')}
    `));
    assertEquals((out.reserve as Record<string, unknown>).allowed, true);
    const settle = out.settle as Record<string, unknown>;
    assertEquals(settle.settled, true);
    assertEquals(settle.real_cost, ESTIMATE + 10_000);
    assertEquals(settle.charged, ESTIMATE, 'the wallet had nothing more to give');
    assertEquals((out.after as Record<string, unknown>).balance, 0);
    assertEquals((out.next as Record<string, unknown>).allowed, false);
  },
});

Deno.test({
  name: 'budget — the monthly budget is spent before bought budget, and a refund goes back to the bought part first',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      perform public.grant_allowance(u, 100000, now() + interval '30 days', 'evt-1');
      perform public.grant_credits(u, 50000, 'grant_purchase', 'pack-1');
      j := public.ai_budget_reserve(u, 'vana-chat', 120000, ${MONTH}, null, 'vana-chat');
      rid := (j->>'reservation_id')::uuid;
      ${wallet('after_reserve')}
      ${reservation('row')}
      -- Real cost 110,000: the 10,000 back is bought budget, since the allowance is what got spent.
      j := public.ai_budget_settle(rid, 110000);
      ${wallet('after_settle')}
      -- A second call costs less than its allowance share: that part comes back to the allowance while the window stands.
      perform public.grant_allowance(u, 100000, now() + interval '30 days', 'evt-2');
      j := public.ai_budget_reserve(u, 'vana-chat', 30000, ${MONTH}, null, 'vana-chat');
      rid := (j->>'reservation_id')::uuid;
      j := public.ai_budget_settle(rid, 10000);
      ${wallet('after_second')}
    `));
    const afterReserve = out.after_reserve as Record<string, unknown>;
    assertEquals(afterReserve.balance, 30000);
    assertEquals(afterReserve.allowance, 0, 'the allowance went first');
    assertEquals((out.row as Record<string, unknown>).from_allowance, 100000);
    const afterSettle = out.after_settle as Record<string, unknown>;
    assertEquals(afterSettle.balance, 40000);
    assertEquals(afterSettle.allowance, 0);
    const afterSecond = out.after_second as Record<string, unknown>;
    assertEquals(afterSecond.allowance, 90000, 'the 20,000 unspent returned to the allowance');
    assertEquals(afterSecond.balance, 130000);
  },
});

Deno.test({
  name: 'budget — 50 old credits become $1.00, once; a wallet already in micro-dollars is left alone',
  ignore: !live,
  async fn() {
    const out = await runScenario(scenario(`
      insert into public.token_wallets (user_id, balance, allowance, allowance_monthly, unit) values (u, 50, 20, 300, 'credit');
      j := to_jsonb(public.ai_budget_convert_credits());
      ${recordJson('converted', 'j')}
      ${wallet('after')}
      ${record('unit', `(select unit from public.token_wallets where user_id = u)`)}
      ${record('ledger', `(select jsonb_agg(jsonb_build_object('reason', reason, 'delta', delta, 'unit', unit, 'after', balance_after)) from public.token_ledger where user_id = u)`)}
      j := to_jsonb(public.ai_budget_convert_credits());
      ${recordJson('again', 'j')}
      ${wallet('after_again')}
    `));
    assertEquals(out.converted, 1);
    const w = out.after as Record<string, unknown>;
    assertEquals(w.balance, 1_000_000, '50 credits at 2 cents is $1.00');
    assertEquals(w.allowance, 400_000);
    assertEquals(w.monthly, 6_000_000);
    assertEquals(out.unit, 'usd_micro');
    assertEquals(out.ledger, [{ reason: 'convert_credits', delta: 1_000_000 - 50, unit: 'usd_micro', after: 1_000_000 }]);
    assertEquals(out.again, 0);
    assertEquals(out.after_again, out.after);
  },
});
