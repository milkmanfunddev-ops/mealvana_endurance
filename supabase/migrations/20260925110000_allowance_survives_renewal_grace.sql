-- =====================================================================
-- 20260925_110000 · The allowance survives the renewal grace
--
-- testing-wave ticket 38 (06-002, mp-457): the server gate keeps Pro
-- RENEWAL_GRACE_MS past `active_until` while `user_entitlements.will_renew`
-- is true (`_shared/vana/entitlement.ts`). Without this, `ensure_allowance`
-- forfeits the allowance at its window end, so inside that grace the gate
-- passes and `ai_budget_reserve` refuses on an empty wallet. Now, while the
-- row says the subscription renews and both the entitlement end and the
-- allowance end are less than the grace in the past, the expired allowance
-- is kept; the late RENEWAL's `grant_allowance` replaces it as usual. Past
-- the grace, or for a row not renewing, it is forfeited as before.
--
-- The grace is named once here, `public.entitlement_renewal_grace()`.
-- KEEP IN STEP with `RENEWAL_GRACE_MS` in
-- supabase/functions/_shared/vana/entitlement.ts: the two must move together.
--
-- `ensure_allowance` keeps the signature and body of 20260922120000 section 3
-- except the forfeit condition (and the two variables it reads).
--
-- Other forfeits, unchanged on purpose:
--   grant_allowance  forfeits the old window when it grants the new one (the
--                    late RENEWAL replacing the kept allowance, as intended);
--   forfeit_allowance the webhook's EXPIRATION, when Pro has ended;
--   debit_credits    no edge function calls it any more (the AI path reserves
--                    through ai_budget_reserve -> ensure_allowance);
--   ai_budget_settle forfeits nothing; it declines to refund into an expired
--                    window, and inside the grace that remainder is replaced
--                    by the RENEWAL grant moments later anyway.
--
-- Needs 20260925100000_user_entitlements_will_renew.sql applied first.
-- Idempotent: safe to re-run.
-- =====================================================================

create or replace function public.entitlement_renewal_grace()
returns interval
language sql immutable
set search_path to 'public'
as $$ select interval '15 minutes' $$;

comment on function public.entitlement_renewal_grace() is
  'How long past active_until a renewing subscription keeps Pro and its allowance while the RENEWAL webhook is late. '
  'Keep in step with RENEWAL_GRACE_MS in supabase/functions/_shared/vana/entitlement.ts.';

create or replace function public.ensure_allowance(p_user_id uuid, p_amount integer, p_trial_amount integer default null)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_balance int; v_allowance int; v_expires timestamptz; v_monthly int;
  v_until timestamptz; v_period text; v_end timestamptz; v_ref text; v_granted boolean := false; v_grant int;
  v_renews boolean; v_renew_until timestamptz;
begin
  insert into public.token_wallets (user_id, balance) values (p_user_id, 0)
    on conflict (user_id) do nothing;
  select balance, allowance, allowance_expires_at, allowance_monthly
    into v_balance, v_allowance, v_expires, v_monthly
    from public.token_wallets where user_id = p_user_id for update;

  -- A renewing subscription inside the grace keeps its expired allowance (testing-wave 38).
  select will_renew, active_until into v_renews, v_renew_until
    from public.user_entitlements where user_id = p_user_id;
  if v_allowance > 0 and v_expires is not null and v_expires <= now()
     and not (coalesce(v_renews, false)
              and v_renew_until is not null and v_renew_until + public.entitlement_renewal_grace() > now()
              and v_expires + public.entitlement_renewal_grace() > now()) then
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

-- Service-role only (Postgres re-grants EXECUTE to PUBLIC on CREATE OR REPLACE).
revoke all on function public.entitlement_renewal_grace() from public, anon, authenticated;
revoke all on function public.ensure_allowance(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.entitlement_renewal_grace() to service_role;
grant execute on function public.ensure_allowance(uuid, integer, integer) to service_role;
