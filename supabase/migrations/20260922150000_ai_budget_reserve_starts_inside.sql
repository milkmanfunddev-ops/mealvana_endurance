-- ai-cost wave 4 review: a call that starts inside the budget runs (mp-436 clause 1).
--
-- 20260922120000 refused a reservation whose estimate did not fit the balance,
-- which is the alternative mp-436 rejected: an athlete with a few cents left was
-- told the month was used up with budget unspent. Now the only refusal is an
-- empty wallet. A call whose estimate exceeds what is left reserves what is
-- left, so the wallet reads zero and the next call is the one refused; the
-- reservation row records what was actually taken as its estimate, which is
-- what ai_budget_settle already settles against.
--
-- Idempotent: create or replace only.

create or replace function public.ai_budget_reserve(
  p_user_id uuid, p_kind text, p_estimate integer, p_monthly integer, p_trial integer default null, p_ref text default null
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_balance int; v_allowance int; v_expires timestamptz; v_monthly int;
  v_take int; v_from_allowance int; v_id uuid;
begin
  if p_estimate <= 0 then raise exception 'estimate must be positive'; end if;
  -- Creates the wallet, takes its row lock, forfeits an expired allowance and
  -- grants the current window when the entitlement is active. The lock is
  -- what makes two requests for one athlete count each other.
  perform public.ensure_allowance(p_user_id, p_monthly, p_trial);
  select balance, allowance, allowance_expires_at, allowance_monthly
    into v_balance, v_allowance, v_expires, v_monthly
    from public.token_wallets where user_id = p_user_id for update;

  -- Only an empty wallet refuses. A call that starts inside the budget runs
  -- even when its estimate is more than what is left (mp-436 clause 1).
  if v_balance <= 0 then
    return jsonb_build_object('allowed', false, 'balance', v_balance, 'allowance', v_allowance,
      'allowance_monthly', v_monthly, 'allowance_expires_at', v_expires);
  end if;

  v_take := least(p_estimate, v_balance);
  v_from_allowance := least(v_allowance, v_take);
  update public.token_wallets
     set balance = balance - v_take,
         allowance = allowance - v_from_allowance,
         updated_at = now()
   where user_id = p_user_id
   returning balance, allowance into v_balance, v_allowance;
  insert into public.token_reservations (user_id, kind, estimate, from_allowance, window_end, ref)
    values (p_user_id, p_kind, v_take, v_from_allowance, v_expires, p_ref)
    returning id into v_id;
  insert into public.token_ledger (user_id, delta, reason, ref, balance_after)
    values (p_user_id, -v_take, 'reserve_usage', v_id::text, v_balance);
  return jsonb_build_object('allowed', true, 'reservation_id', v_id, 'balance', v_balance, 'allowance', v_allowance,
    'allowance_monthly', v_monthly, 'allowance_expires_at', v_expires);
end $$;
