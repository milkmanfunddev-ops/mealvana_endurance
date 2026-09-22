-- =====================================================================
-- 20260922_120000 · The monthly budget, metered in real cost (mp-430, mp-436)
--
-- ai-cost ticket 09, approved as mp-474. The wallet stops counting credits
-- and counts whole MICRO-DOLLARS of model cost: $4.00 is 4,000,000. Nothing
-- about the wallet's shape changes (`balance`, `allowance`,
-- `allowance_monthly`, `allowance_expires_at`, the ledger); only the unit,
-- and the way a call spends it:
--
--   * ai_budget_reserve — before the model runs. One statement, under the
--     wallet's row lock: roll the allowance (ensure_allowance), check the
--     balance against the call's ESTIMATE, debit the estimate allowance-first,
--     write a reservation. Parallel requests for one athlete queue on the
--     lock, so a burst cannot pass the budget (mp-430 clause 9). A refusal
--     writes nothing.
--   * ai_budget_settle — after the model answered, with the REAL cost. The
--     difference is taken or given back. A call that started inside the
--     budget finishes even if it ends over (mp-436 clause 1): the wallet
--     floors at zero and the next reservation is refused. A refund goes back
--     where it came from — the pack part first (the allowance is spent first,
--     so it is what the real cost consumed), then the allowance, but only
--     while its window is still the one the estimate was drawn from; an
--     allowance that rolled meanwhile was forfeited anyway.
--   * a failed call settles at 0, which is a full refund. A reservation
--     nothing settled (an isolate that died) is released after two hours.
--
-- Credits already in wallets convert ONCE at 2 cents each (mp-436 clause 2),
-- the rate the packs imply. The `unit` column is the guard: a wallet still
-- in 'credit' is converted and marked; a wallet born after this migration is
-- 'usd_micro' from the start. Ledger rows keep the unit they were written in.
--
-- The amounts ($4.00 a month, $1.00 for the trial week, the packs, the free
-- grant's end date) are NOT here: they are one setting each in
-- supabase/functions/_shared/ai/allowance.ts and arrive as parameters, so
-- SQL never carries a second copy of a price.
--
-- Service-role only, like the other wallet RPCs. Idempotent: safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------------
-- 1 · The unit, and the one-time conversion
-- ---------------------------------------------------------------------------

alter table public.token_wallets
  add column if not exists unit text not null default 'credit';
alter table public.token_ledger
  add column if not exists unit text not null default 'credit';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'token_wallets_unit_check') then
    alter table public.token_wallets
      add constraint token_wallets_unit_check check (unit in ('credit', 'usd_micro'));
  end if;
end $$;

comment on column public.token_wallets.unit is
  '''usd_micro'': balance, allowance and allowance_monthly are whole micro-dollars of model cost (mp-430). ''credit'' only on a wallet the conversion has not reached.';
comment on column public.token_ledger.unit is
  'The unit `delta` and `balance_after` were written in: ''credit'' before the budget migration, ''usd_micro'' after.';

-- Every ledger row from here on is in micro-dollars; the rows already there
-- keep 'credit' (the default they were given when the column was added).
alter table public.token_ledger alter column unit set default 'usd_micro';

-- Convert what is still in credits: 1 credit = 20,000 micro-dollars (2 cents).
-- The conversion row's delta is the growth, so `balance_after` stays a true
-- running balance in the new unit.
create or replace function public.ai_budget_convert_credits(p_rate integer default 20000)
returns integer
language plpgsql security definer
set search_path to 'public'
as $$
declare w record; v_new_balance integer; n integer := 0;
begin
  for w in select user_id, balance, allowance, allowance_monthly from public.token_wallets where unit = 'credit' for update loop
    v_new_balance := w.balance * p_rate;
    update public.token_wallets
       set balance = v_new_balance,
           allowance = w.allowance * p_rate,
           allowance_monthly = w.allowance_monthly * p_rate,
           unit = 'usd_micro',
           updated_at = now()
     where user_id = w.user_id;
    insert into public.token_ledger (user_id, delta, reason, ref, balance_after, unit)
      values (w.user_id, v_new_balance - w.balance, 'convert_credits', 'credit->usd_micro@' || p_rate::text, v_new_balance, 'usd_micro');
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public.ai_budget_convert_credits(integer) from public, anon, authenticated;

select public.ai_budget_convert_credits();

-- A wallet born from now on is in micro-dollars.
alter table public.token_wallets alter column unit set default 'usd_micro';

-- ---------------------------------------------------------------------------
-- 2 · Reservations: a call's place in the budget, from start to settle
-- ---------------------------------------------------------------------------

create table if not exists public.token_reservations (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  kind            text not null,                       -- 'vana-chat' | 'vana-opener' | 'describe-meal' | …
  estimate        integer not null check (estimate > 0),
  from_allowance  integer not null default 0 check (from_allowance >= 0),
  window_end      timestamptz,                         -- the allowance window the estimate was drawn from
  ref             text,                                -- what reserved it (function name, call id)
  real_cost       integer,                             -- what the call actually cost; null until settled
  charged         integer,                             -- what the wallet actually gave up
  created_at      timestamptz not null default now(),
  settled_at      timestamptz
);
create index if not exists token_reservations_open_idx
  on public.token_reservations (created_at) where settled_at is null;
create index if not exists token_reservations_user_created
  on public.token_reservations (user_id, created_at desc);

alter table public.token_reservations enable row level security;
drop policy if exists "Users read own reservations" on public.token_reservations;
create policy "Users read own reservations"
  on public.token_reservations for select using (user_id = auth.uid());

comment on table public.token_reservations is
  'One row per debiting AI call (mp-436): the estimate reserved when it started, the real cost it settled to, what the wallet gave up. Micro-dollars.';

-- ---------------------------------------------------------------------------
-- 3 · ensure_allowance learns the trial's amount
-- ---------------------------------------------------------------------------
-- The trial week gets a quarter of the month (mp-430 clause 3). The webhook
-- grants that on INITIAL_PURCHASE; this is the roll for a grant the webhook
-- missed, so it has to know the trial's number too. The entitlement's
-- period_type says which one applies. Same body as 20260916130000 otherwise.
drop function if exists public.ensure_allowance(uuid, integer);
create or replace function public.ensure_allowance(p_user_id uuid, p_amount integer, p_trial_amount integer default null)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_balance int; v_allowance int; v_expires timestamptz; v_monthly int;
  v_until timestamptz; v_period text; v_end timestamptz; v_ref text; v_granted boolean := false; v_grant int;
begin
  insert into public.token_wallets (user_id, balance) values (p_user_id, 0)
    on conflict (user_id) do nothing;
  select balance, allowance, allowance_expires_at, allowance_monthly
    into v_balance, v_allowance, v_expires, v_monthly
    from public.token_wallets where user_id = p_user_id for update;

  if v_allowance > 0 and v_expires is not null and v_expires <= now() then
    perform public._forfeit_allowance_locked(p_user_id, 'expired:' || to_char(v_expires at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  end if;

  if p_amount > 0 and (v_expires is null or v_expires <= now()) then
    select active_until, period_type into v_until, v_period from public.user_entitlements where user_id = p_user_id;
    if v_until is not null and v_until > now() then
      v_grant := case when v_period = 'TRIAL' then coalesce(p_trial_amount, p_amount) else p_amount end;
      v_end := public.allowance_window_end(v_until, now());
      v_ref := 'allowance:' || p_user_id::text || ':' || to_char(v_end at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
      if not exists (select 1 from public.token_ledger where reason = 'grant_allowance' and ref = v_ref) then
        perform public.grant_allowance(p_user_id, v_grant, v_until, v_ref);
        v_granted := true;
      end if;
    end if;
  end if;

  select balance, allowance, allowance_expires_at, allowance_monthly
    into v_balance, v_allowance, v_expires, v_monthly
    from public.token_wallets where user_id = p_user_id;
  return jsonb_build_object('balance', v_balance, 'allowance', v_allowance,
    'allowance_monthly', v_monthly, 'allowance_expires_at', v_expires, 'granted', v_granted);
end $$;

-- ---------------------------------------------------------------------------
-- 4 · Reserve: one atomic statement that also checks the balance
-- ---------------------------------------------------------------------------
create or replace function public.ai_budget_reserve(
  p_user_id uuid, p_kind text, p_estimate integer, p_monthly integer, p_trial integer default null, p_ref text default null
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_balance int; v_allowance int; v_expires timestamptz; v_monthly int;
  v_from_allowance int; v_id uuid;
begin
  if p_estimate <= 0 then raise exception 'estimate must be positive'; end if;
  -- Creates the wallet, takes its row lock, forfeits an expired allowance and
  -- grants the current window when the entitlement is active. The lock is
  -- what makes two requests for one athlete count each other.
  perform public.ensure_allowance(p_user_id, p_monthly, p_trial);
  select balance, allowance, allowance_expires_at, allowance_monthly
    into v_balance, v_allowance, v_expires, v_monthly
    from public.token_wallets where user_id = p_user_id for update;

  if v_balance < p_estimate then
    return jsonb_build_object('allowed', false, 'balance', v_balance, 'allowance', v_allowance,
      'allowance_monthly', v_monthly, 'allowance_expires_at', v_expires);
  end if;

  v_from_allowance := least(v_allowance, p_estimate);
  update public.token_wallets
     set balance = balance - p_estimate,
         allowance = allowance - v_from_allowance,
         updated_at = now()
   where user_id = p_user_id
   returning balance, allowance into v_balance, v_allowance;
  insert into public.token_reservations (user_id, kind, estimate, from_allowance, window_end, ref)
    values (p_user_id, p_kind, p_estimate, v_from_allowance, v_expires, p_ref)
    returning id into v_id;
  insert into public.token_ledger (user_id, delta, reason, ref, balance_after)
    values (p_user_id, -p_estimate, 'reserve_usage', v_id::text, v_balance);
  return jsonb_build_object('allowed', true, 'reservation_id', v_id, 'balance', v_balance, 'allowance', v_allowance,
    'allowance_monthly', v_monthly, 'allowance_expires_at', v_expires);
end $$;

-- ---------------------------------------------------------------------------
-- 5 · Settle: the reservation becomes the real cost (0 = a full refund)
-- ---------------------------------------------------------------------------
create or replace function public.ai_budget_settle(p_id uuid, p_real_cost integer)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  r record;
  v_balance int; v_allowance int; v_expires timestamptz;
  v_diff int; v_take int; v_take_allowance int;
  v_refund int; v_refund_pack int; v_refund_allowance int;
  v_charged int; v_reason text;
begin
  if p_real_cost < 0 then raise exception 'real cost cannot be negative'; end if;
  select * into r from public.token_reservations where id = p_id for update;
  if not found then
    return jsonb_build_object('settled', false, 'reason', 'not_found');
  end if;
  if r.settled_at is not null then
    return jsonb_build_object('settled', false, 'reason', 'already_settled', 'real_cost', r.real_cost, 'charged', r.charged);
  end if;
  select balance, allowance, allowance_expires_at into v_balance, v_allowance, v_expires
    from public.token_wallets where user_id = r.user_id for update;

  v_diff := p_real_cost - r.estimate;
  v_charged := r.estimate;
  if v_diff > 0 then
    -- Over the estimate. The call finishes whatever it cost (mp-436 clause 1);
    -- the wallet gives what it has and floors at zero. What it could not give
    -- is visible as real_cost - charged.
    v_take := least(v_diff, v_balance);
    v_take_allowance := least(v_allowance, v_take);
    if v_take > 0 then
      update public.token_wallets
         set balance = balance - v_take, allowance = allowance - v_take_allowance, updated_at = now()
       where user_id = r.user_id
       returning balance, allowance into v_balance, v_allowance;
      insert into public.token_ledger (user_id, delta, reason, ref, balance_after)
        values (r.user_id, -v_take, 'settle_usage', p_id::text, v_balance);
    end if;
    v_charged := r.estimate + v_take;
  elsif v_diff < 0 then
    -- Under the estimate (or failed, at 0). Back where it came from: the pack
    -- part first, since the allowance part is what the real cost consumed;
    -- the allowance part only while its window is still the one it left.
    v_refund := -v_diff;
    v_refund_pack := least(v_refund, r.estimate - r.from_allowance);
    v_refund_allowance := v_refund - v_refund_pack;
    if v_refund_allowance > 0 and not (v_expires is not null and v_expires = r.window_end and v_expires > now()) then
      v_refund_allowance := 0;  -- that window closed; its remainder was forfeited, this would have been too
    end if;
    if v_refund_pack + v_refund_allowance > 0 then
      update public.token_wallets
         set balance = balance + v_refund_pack + v_refund_allowance,
             allowance = allowance + v_refund_allowance,
             updated_at = now()
       where user_id = r.user_id
       returning balance, allowance into v_balance, v_allowance;
      v_reason := case when p_real_cost = 0 then 'refund_usage' else 'settle_usage' end;
      insert into public.token_ledger (user_id, delta, reason, ref, balance_after)
        values (r.user_id, v_refund_pack + v_refund_allowance, v_reason, p_id::text, v_balance);
    end if;
    v_charged := r.estimate - v_refund_pack - v_refund_allowance;
  end if;

  update public.token_reservations
     set settled_at = now(), real_cost = p_real_cost, charged = v_charged
   where id = p_id;
  return jsonb_build_object('settled', true, 'real_cost', p_real_cost, 'charged', v_charged,
    'balance', v_balance, 'allowance', v_allowance);
end $$;

-- ---------------------------------------------------------------------------
-- 6 · Release what nothing settled
-- ---------------------------------------------------------------------------
-- An edge function that died between reserve and settle leaves the estimate
-- taken for a call the athlete may or may not have received. After two hours
-- (no function runs that long) it is given back in full.
create or replace function public.ai_budget_release_stale(p_older_than interval default interval '2 hours')
returns integer
language plpgsql security definer
set search_path to 'public'
as $$
declare r record; n int := 0;
begin
  for r in select id from public.token_reservations
            where settled_at is null and created_at < now() - p_older_than
            order by created_at loop
    perform public.ai_budget_settle(r.id, 0);
    n := n + 1;
  end loop;
  return n;
end $$;

create extension if not exists pg_cron;
do $$
begin
  if exists (select 1 from cron.job where jobname = 'ai-budget-release-stale') then
    perform cron.unschedule('ai-budget-release-stale');
  end if;
  perform cron.schedule('ai-budget-release-stale', '7 * * * *', $job$ select public.ai_budget_release_stale(); $job$);
end $$;

-- ---------------------------------------------------------------------------
-- 7 · Service-role only (Postgres re-grants EXECUTE to PUBLIC on CREATE OR REPLACE)
-- ---------------------------------------------------------------------------
revoke all on function public.ensure_allowance(uuid, integer, integer) from public, anon, authenticated;
revoke all on function public.ai_budget_reserve(uuid, text, integer, integer, integer, text) from public, anon, authenticated;
revoke all on function public.ai_budget_settle(uuid, integer) from public, anon, authenticated;
revoke all on function public.ai_budget_release_stale(interval) from public, anon, authenticated;
grant execute on function public.ensure_allowance(uuid, integer, integer) to service_role;
grant execute on function public.ai_budget_reserve(uuid, text, integer, integer, integer, text) to service_role;
grant execute on function public.ai_budget_settle(uuid, integer) to service_role;
grant execute on function public.ai_budget_release_stale(interval) to service_role;
