-- The daily AI cost alert without a cron job (mp-523 rejected 2026-09-23: "i want to minimize cron jobs if possible").
--
-- Before: the pg_cron job `ai-cost-daily-alert` ran `vana_daily_cost_alert()` at 06:23 UTC and reported every account
-- whose logged gateway charge for YESTERDAY was over $1.50. Lee chose option (b) in the terminal: report at the
-- moment an athlete's spend for the day passes $1.50, inside the write that pushes it over.
--
-- After: an AFTER trigger on `vana_calls` fires when a row's `gateway_cost_usd` is written (the insert from `logCall`,
-- or the update from `completeCall` that settles a reserved row). It sums the account's charge for the row's UTC day
-- and, only when that sum just crossed the threshold with this row, posts the one account to the `ai-cost-alert` edge
-- function through pg_net, as the cron did. One report per account per day.
--
-- Still reports and refuses nothing: the trigger can never fail or slow the write it rides on beyond one indexed sum
-- (`vana_calls_user_created_idx`), every error is swallowed into a NOTICE, and pg_net sends after commit.
-- Known edge: two charges for the same account committing at the same instant can each miss the other's row, so a
-- crossing may be reported by the next charge that day instead. Sentry's fingerprint (account, day) keeps a double
-- report to one issue.
--
-- Idempotent. Vault secrets are unchanged (`ai_cost_alert_url`, `ai_cost_alert_token`, seeded per env).

-- 1 · The cron job and its wrapper go.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from cron.job where jobname = 'ai-cost-daily-alert') then
    perform cron.unschedule('ai-cost-daily-alert');
  end if;
end $$;

drop function if exists public.vana_daily_cost_alert(date, numeric);

-- `vana_daily_cost_offenders(day, threshold)` stays: it is the read-only question "who was over on this day", useful
-- by hand and unchanged.

-- 2 · The crossing, as a pure function so it can be checked at any numbers.
create or replace function public.vana_cost_crossed(p_before numeric, p_after numeric, p_threshold numeric default 1.50)
returns boolean
language sql immutable
as $$ select coalesce(p_before, 0) <= p_threshold and coalesce(p_after, 0) > p_threshold $$;

revoke execute on function public.vana_cost_crossed(numeric, numeric, numeric) from public, anon, authenticated;

-- 3 · The trigger. SECURITY DEFINER so it can read Vault and call pg_net whoever writes the row (the edge functions
--     write as service_role); search_path pinned.
create or replace function public.vana_cost_alert_on_charge()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_threshold constant numeric := 1.50;
  v_added numeric := coalesce(new.gateway_cost_usd, 0) - (case when tg_op = 'UPDATE' then coalesce(old.gateway_cost_usd, 0) else 0 end);
  v_day date := (new.created_at at time zone 'UTC')::date;
  v_after numeric;
  v_calls bigint;
  v_costed bigint;
  v_url text;
  v_token text;
begin
  if v_added <= 0 or new.user_id is null then
    return null;
  end if;

  begin
    select coalesce(sum(coalesce(c.gateway_cost_usd, 0)), 0), count(*), count(c.gateway_cost_usd)
      into v_after, v_calls, v_costed
      from public.vana_calls c
     where c.user_id = new.user_id
       and c.created_at >= (v_day::timestamp at time zone 'UTC')
       and c.created_at <  ((v_day + 1)::timestamp at time zone 'UTC');

    if public.vana_cost_crossed(v_after - v_added, v_after, v_threshold) then
      select decrypted_secret into v_url   from vault.decrypted_secrets where name = 'ai_cost_alert_url';
      select decrypted_secret into v_token from vault.decrypted_secrets where name = 'ai_cost_alert_token';
      if v_url is null or v_token is null then
        raise notice 'ai-cost alert: % crossed $% on % but the vault secrets are not seeded — Sentry report skipped',
          new.user_id, v_threshold, v_day;
      else
        perform net.http_post(
          url := v_url,
          headers := jsonb_build_object('Content-Type', 'application/json', 'x-alert-token', v_token),
          body := jsonb_build_object(
            'day', v_day,
            'threshold_usd', v_threshold,
            'accounts', jsonb_build_array(jsonb_build_object(
              'user_id', new.user_id, 'day', v_day, 'cost_usd', round(v_after, 6), 'calls', v_calls, 'costed_calls', v_costed)))
        );
      end if;
    end if;
  exception when others then
    raise notice 'ai-cost alert check failed for %: %', new.user_id, sqlerrm;
  end;

  return null;
end $$;

revoke execute on function public.vana_cost_alert_on_charge() from public, anon, authenticated;

drop trigger if exists vana_calls_cost_alert on public.vana_calls;
create trigger vana_calls_cost_alert
  after insert or update of gateway_cost_usd on public.vana_calls
  for each row
  when (new.gateway_cost_usd is not null)
  execute function public.vana_cost_alert_on_charge();

comment on function public.vana_cost_alert_on_charge() is
  'Reports an account to the ai-cost-alert function the moment its gateway charge for the UTC day passes $1.50 (mp-523 option b, replacing the ai-cost-daily-alert cron). Reports, refuses nothing, never fails the write.';
