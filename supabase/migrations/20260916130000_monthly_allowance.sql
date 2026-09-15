-- =====================================================================
-- 20260916_130000 · The monthly Allowance lives in the wallet (mp-281)
--
-- The subscription carries a monthly allowance of credits, granted into the
-- same `token_wallets` row the packs fill. `balance` stays the total the
-- debit path checks (allowance + pack credits); `allowance` is how much of
-- that total is this period's grant, `allowance_expires_at` is when it dies,
-- `allowance_monthly` is the size of the grant (the number the top-up sheet
-- shows). Invariant kept by the functions below: 0 <= allowance <= balance.
--
-- Rules (mp-281, mp-298):
--   * grant_allowance — the webhook's INITIAL_PURCHASE / RENEWAL: whatever is
--     left of the previous allowance is forfeited (it never rolls over), then
--     the full grant lands. Idempotent on the RevenueCat event id (ledger
--     unique index). The grant expires at the end of the current monthly
--     window: the period end for a monthly plan or a trial, the next
--     anniversary day for an annual plan (allowance_window_end).
--   * debit_credits — spends the allowance first, then pack credits. An
--     expired allowance is forfeited before the check, so a late or missed
--     webhook can never let it roll over.
--   * forfeit_allowance — the webhook's EXPIRATION (a cancelled trial ends,
--     a lapsed subscription): the remainder goes; pack credits are untouched.
--   * ensure_allowance — the roll for annual plans and for a grant the
--     webhook missed: called by the AI functions before each debiting call,
--     it forfeits an expired allowance and, when the entitlement is active
--     and no window is open, grants the current window.
--
-- Service-role only, like the other credit RPCs (20260728090000).
-- Idempotent: safe to re-run.
-- =====================================================================

alter table public.token_wallets
  add column if not exists allowance            integer not null default 0,
  add column if not exists allowance_monthly    integer not null default 0,
  add column if not exists allowance_expires_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'token_wallets_allowance_check'
  ) then
    alter table public.token_wallets
      add constraint token_wallets_allowance_check check (allowance >= 0 and allowance <= balance);
  end if;
end $$;

comment on column public.token_wallets.allowance is
  'Credits left of this period''s subscription allowance (mp-281); part of balance, spent first, never rolls over.';
comment on column public.token_wallets.allowance_monthly is
  'Size of the allowance grant the subscription carries; 0 until the first grant.';
comment on column public.token_wallets.allowance_expires_at is
  'End of the current allowance window; what is left is forfeited at this time.';

-- One grant per RevenueCat event (or per computed window), like packs.
create unique index if not exists token_ledger_allowance_ref_uniq
  on public.token_ledger (ref)
  where reason = 'grant_allowance' and ref is not null;

-- ── The monthly window ────────────────────────────────────────────────────
-- The last whole-month step back from `p_active_until` that still ends after
-- `p_now`: the period end itself for a monthly plan or a trial, the next
-- anniversary day for an annual plan.
create or replace function public.allowance_window_end(p_active_until timestamptz, p_now timestamptz)
returns timestamptz
language plpgsql stable
as $$
declare v_end timestamptz := p_active_until;
begin
  if p_active_until is null then return null; end if;
  while v_end - interval '1 month' > p_now loop
    v_end := v_end - interval '1 month';
  end loop;
  return v_end;
end $$;

-- ── Forfeit (caller holds the row lock) ───────────────────────────────────
create or replace function public._forfeit_allowance_locked(p_user_id uuid, p_ref text)
returns integer
language plpgsql security definer
set search_path to 'public'
as $$
declare v_allowance int; v_balance int; v_forfeit int;
begin
  select allowance, balance into v_allowance, v_balance
    from public.token_wallets where user_id = p_user_id;
  if v_allowance is null then return 0; end if;
  v_forfeit := least(v_allowance, v_balance);
  update public.token_wallets
     set balance = balance - v_forfeit,
         allowance = 0,
         allowance_expires_at = null,
         updated_at = now()
   where user_id = p_user_id
   returning balance into v_balance;
  if v_forfeit > 0 then
    insert into public.token_ledger (user_id, delta, reason, ref, balance_after)
      values (p_user_id, -v_forfeit, 'forfeit_allowance', p_ref, v_balance);
  end if;
  return v_forfeit;
end $$;

-- ── Grant ─────────────────────────────────────────────────────────────────
create or replace function public.grant_allowance(
  p_user_id uuid, p_amount integer, p_active_until timestamptz, p_ref text
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_forfeited int; v_balance int; v_allowance int; v_expires timestamptz;
begin
  if p_amount <= 0 then raise exception 'allowance must be positive'; end if;
  if p_active_until is null then raise exception 'allowance needs an active_until'; end if;
  insert into public.token_wallets (user_id, balance) values (p_user_id, 0)
    on conflict (user_id) do nothing;
  perform 1 from public.token_wallets where user_id = p_user_id for update;

  -- Already granted for this event / window: answer with the wallet as it is.
  if p_ref is not null and exists (
    select 1 from public.token_ledger where reason = 'grant_allowance' and ref = p_ref
  ) then
    select balance, allowance, allowance_expires_at into v_balance, v_allowance, v_expires
      from public.token_wallets where user_id = p_user_id;
    return jsonb_build_object('granted', false, 'forfeited', 0,
      'balance', v_balance, 'allowance', v_allowance, 'allowance_expires_at', v_expires);
  end if;

  v_forfeited := public._forfeit_allowance_locked(p_user_id, p_ref);
  v_expires := public.allowance_window_end(p_active_until, now());
  update public.token_wallets
     set balance = balance + p_amount,
         allowance = p_amount,
         allowance_monthly = p_amount,
         allowance_expires_at = v_expires,
         updated_at = now()
   where user_id = p_user_id
   returning balance, allowance into v_balance, v_allowance;
  insert into public.token_ledger (user_id, delta, reason, ref, balance_after)
    values (p_user_id, p_amount, 'grant_allowance', p_ref, v_balance);
  return jsonb_build_object('granted', true, 'forfeited', v_forfeited,
    'balance', v_balance, 'allowance', v_allowance, 'allowance_expires_at', v_expires);
end $$;

-- ── Forfeit (public entry: the webhook's EXPIRATION) ──────────────────────
create or replace function public.forfeit_allowance(p_user_id uuid, p_ref text)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_forfeited int; v_balance int;
begin
  perform 1 from public.token_wallets where user_id = p_user_id for update;
  v_forfeited := public._forfeit_allowance_locked(p_user_id, p_ref);
  select balance into v_balance from public.token_wallets where user_id = p_user_id;
  return jsonb_build_object('forfeited', v_forfeited, 'balance', coalesce(v_balance, 0), 'allowance', 0);
end $$;

-- ── Debit: allowance first, then packs ────────────────────────────────────
create or replace function public.debit_credits(
  p_user_id uuid, p_amount integer, p_reason text, p_ref text default null
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_balance int; v_allowance int; v_expires timestamptz; v_from_allowance int;
begin
  if p_amount <= 0 then raise exception 'debit amount must be positive'; end if;
  select balance, allowance, allowance_expires_at into v_balance, v_allowance, v_expires
    from public.token_wallets where user_id = p_user_id for update;
  if v_balance is null then
    return jsonb_build_object('success', false, 'balance', 0, 'allowance', 0);
  end if;
  -- An allowance past its window is gone before anything is spent.
  if v_allowance > 0 and v_expires is not null and v_expires <= now() then
    perform public._forfeit_allowance_locked(p_user_id, 'expired:' || to_char(v_expires at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
    select balance, allowance into v_balance, v_allowance
      from public.token_wallets where user_id = p_user_id;
  end if;
  if v_balance < p_amount then
    return jsonb_build_object('success', false, 'balance', v_balance, 'allowance', v_allowance);
  end if;
  v_from_allowance := least(v_allowance, p_amount);
  update public.token_wallets
     set balance = balance - p_amount,
         allowance = allowance - v_from_allowance,
         updated_at = now()
   where user_id = p_user_id
   returning balance, allowance into v_balance, v_allowance;
  insert into public.token_ledger (user_id, delta, reason, ref, balance_after)
    values (p_user_id, -p_amount, p_reason, p_ref, v_balance);
  return jsonb_build_object('success', true, 'balance', v_balance, 'allowance', v_allowance,
    'from_allowance', v_from_allowance);
end $$;

-- ── Ensure: the roll the webhook cannot do monthly ────────────────────────
create or replace function public.ensure_allowance(p_user_id uuid, p_amount integer)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_balance int; v_allowance int; v_expires timestamptz; v_monthly int;
  v_until timestamptz; v_end timestamptz; v_ref text; v_granted boolean := false;
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
    select active_until into v_until from public.user_entitlements where user_id = p_user_id;
    if v_until is not null and v_until > now() then
      v_end := public.allowance_window_end(v_until, now());
      v_ref := 'allowance:' || p_user_id::text || ':' || to_char(v_end at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
      if not exists (select 1 from public.token_ledger where reason = 'grant_allowance' and ref = v_ref) then
        perform public.grant_allowance(p_user_id, p_amount, v_until, v_ref);
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

-- ── Service-role only (Postgres re-grants EXECUTE to PUBLIC on CREATE OR REPLACE) ──
revoke all on function public._forfeit_allowance_locked(uuid, text) from public, anon, authenticated;
revoke all on function public.grant_allowance(uuid, integer, timestamptz, text) from public, anon, authenticated;
revoke all on function public.forfeit_allowance(uuid, text) from public, anon, authenticated;
revoke all on function public.debit_credits(uuid, integer, text, text) from public, anon, authenticated;
revoke all on function public.ensure_allowance(uuid, integer) from public, anon, authenticated;
grant execute on function public.grant_allowance(uuid, integer, timestamptz, text) to service_role;
grant execute on function public.forfeit_allowance(uuid, text) to service_role;
grant execute on function public.debit_credits(uuid, integer, text, text) to service_role;
grant execute on function public.ensure_allowance(uuid, integer) to service_role;
