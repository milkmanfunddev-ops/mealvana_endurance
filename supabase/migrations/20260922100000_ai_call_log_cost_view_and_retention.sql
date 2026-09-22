-- =====================================================================
-- 20260922_100000 · The call log can say what every athlete costs
--
-- ai-cost ticket 05 (mp-420 clause 6, mp-464 clause 7, approved as mp-470).
-- October's traffic is what sets the monthly budget, so by October the log has
-- to be able to answer. Three pieces, in order:
--
--   1. `vana_calls` gains the columns the answer needs: the cache both
--      directions, the FIRST step's prompt (the only step that can read the
--      shared prefix from cache), the step count, the gateway's own charge,
--      whether the turn drew the budget, tap-or-typed, and the subscriber's
--      `user_entitlements` pair as it stood at the call.
--   2. One saved weekly view, `public.vana_weekly_cost`, gives the five
--      figures Lee reads: cost per athlete by plan, the first-step cache hit
--      rate, cost per confirmed plan, spend in conversations that never add a
--      meal, and the share of turns that were fixed-label taps.
--   3. Raw rows in the three AI log tables are swept after 90 days and the
--      weekly rollup is kept, so the history that sets next year's numbers
--      survives its own rows. A daily check reports any account over $1.50 in
--      a day to Sentry and refuses nothing.
--
-- Why the plan is a LABEL and not a stored column: `user_entitlements` is the
-- two-field cache of RevenueCat (mp-285) — `active_until` and `period_type`,
-- with the store product id deliberately dropped. So the log stores that raw
-- pair and `vana_plan_label` names the plan from it. The label can be re-cut
-- when the products change, with no backfill and no second source of truth.
--
-- Cost convention: the gateway's own charge (`gateway_cost_usd`) is the only
-- cost this migration knows. It does NOT price tokens from a table — that
-- table belongs to the monthly budget (mp-436, ai-cost ticket 09), and two
-- price tables would be two answers. Rows from before this migration have no
-- charge, so every cost figure carries `costed_calls` / `calls` beside it: a
-- week whose cost is understated says so instead of reading low.
--
-- Additive and idempotent, and safe to re-run. Apply to dev; prod follows the
-- deploy playbook with Lee's go.
-- =====================================================================

-- ---------------------------------------------------------------------------
-- 1 · The columns
-- ---------------------------------------------------------------------------

alter table public.vana_calls
  add column if not exists cache_write_tokens           integer,
  add column if not exists first_step_input_tokens      integer,
  add column if not exists first_step_cache_read_tokens integer,
  add column if not exists steps                        integer,
  add column if not exists gateway_cost_usd             numeric,
  add column if not exists debited                      boolean,
  add column if not exists input_mode                   text,
  add column if not exists subscriber_period_type       text,
  add column if not exists subscriber_active_until      timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'vana_calls_input_mode_check') then
    alter table public.vana_calls
      add constraint vana_calls_input_mode_check check (input_mode is null or input_mode in ('tap', 'typed'));
  end if;
end $$;

comment on column public.vana_calls.cache_write_tokens is
  'Prompt-cache WRITE tokens the provider reported. A write bills more than an uncached read, so a churning prefix and a warm one look the same without this (mp-420 clause 6).';
comment on column public.vana_calls.first_step_input_tokens is
  'Prompt tokens of the turn''s FIRST model step. Only the first step can read the shared prefix from cache; later steps read what this same call just wrote, so a whole-turn ratio flatters the cache.';
comment on column public.vana_calls.first_step_cache_read_tokens is
  'Of first_step_input_tokens, how many were served from the prompt cache. The numerator of the hit rate mp-420 is measured against.';
comment on column public.vana_calls.steps is 'Model steps in the turn. A runaway tool loop is many billed calls even when each is short.';
comment on column public.vana_calls.gateway_cost_usd is
  'The AI Gateway''s OWN charge for the call, summed over its steps (never our arithmetic). Null = the gateway reported nothing, which is not the same as free.';
comment on column public.vana_calls.debited is 'Whether this call drew the athlete''s budget (mp-420 clause 6).';
comment on column public.vana_calls.input_mode is
  '''tap'' | ''typed'' — what the athlete did to send the message (mp-464 clause 7). Null for the scripted opener and every background job.';
comment on column public.vana_calls.subscriber_period_type is
  'RevenueCat period_type from user_entitlements as it stood at the call: NORMAL | TRIAL | INTRO | PROMOTIONAL. Null = no entitlement row.';
comment on column public.vana_calls.subscriber_active_until is
  'user_entitlements.active_until as it stood at the call. With period_type this is what vana_plan_label reads; the plan label is never stored.';

-- The weekly view and the daily alert both scan by time, and the sweep deletes by it.
create index if not exists vana_calls_created_at_idx on public.vana_calls (created_at);
create index if not exists vana_calls_user_created_idx on public.vana_calls (user_id, created_at);
create index if not exists ai_usage_created_at_idx on public.ai_usage (created_at);
create index if not exists plan_generation_log_created_at_idx on public.plan_generation_log (created_at);

-- ---------------------------------------------------------------------------
-- 2 · The plan label
-- ---------------------------------------------------------------------------
-- Named from the raw pair, at the moment of the call:
--   no row / lapsed  → 'none'         (a call from an account with no live entitlement)
--   TRIAL / INTRO    → 'trial'        (the trial state the ticket asks for, and not a plan)
--   PROMOTIONAL      → 'promotional'  (a tester or comped grant — never a paying cohort)
--   NORMAL, access more than 45 days out → 'annual'
--   NORMAL, otherwise                    → 'monthly'
-- The 45-day cut is what separates the two paying plans without the product id.
-- It is exact for the traffic it was built for: a monthly subscriber's access
-- is never more than ~31 days out, and October's annual subscribers bought in
-- October. It misreads an annual subscriber in the last 45 days of their year
-- as monthly, which is why the raw pair is stored and this is only a label.
create or replace function public.vana_plan_label(
  p_period_type   text,
  p_active_until  timestamptz,
  p_at            timestamptz
) returns text
language sql immutable parallel safe
set search_path = public
as $$
  select case
    when p_active_until is null or p_active_until <= p_at then 'none'
    when upper(coalesce(p_period_type, '')) in ('TRIAL', 'INTRO') then 'trial'
    when upper(coalesce(p_period_type, '')) = 'PROMOTIONAL' then 'promotional'
    when p_active_until > p_at + interval '45 days' then 'annual'
    else 'monthly'
  end
$$;

comment on function public.vana_plan_label(text, timestamptz, timestamptz) is
  'The plan a vana_calls row belongs to, named from the stored user_entitlements pair (ai-cost ticket 05). Never stored — re-cut here when the products change.';

-- ---------------------------------------------------------------------------
-- 3 · One row per call, with everything the figures need already joined
-- ---------------------------------------------------------------------------
-- Two facts about a conversation the figures turn on, and neither lives on the
-- call row: did that conversation ever put a meal in a plan, and did its plan
-- get confirmed. `meal_plans.conversation_id` is the link, `plan_meals` the
-- proof a meal was added. Tool names are deliberately not consulted: meals
-- reach a plan through updateBatch, draftWeek, planDay, planWeek and
-- sameAsLastTime, and that list changes with the persona.
create or replace view public.vana_call_facts
with (security_invoker = true) as
  select
    c.id,
    c.user_id,
    c.conversation_id,
    c.function_name,
    c.model,
    c.created_at,
    date_trunc('week', c.created_at)::date                             as week_start,
    (c.created_at at time zone 'UTC')::date                            as call_day,
    public.vana_plan_label(c.subscriber_period_type, c.subscriber_active_until, c.created_at) as plan,
    c.input_tokens,
    c.output_tokens,
    c.cache_read_tokens,
    c.cache_write_tokens,
    c.first_step_input_tokens,
    c.first_step_cache_read_tokens,
    c.steps,
    c.gateway_cost_usd,
    c.debited,
    c.input_mode,
    -- A planning turn: the conversation kind is on the function name the reservation settled.
    (c.function_name like '%meal_planning') as is_planning,
    exists (
      select 1
        from public.meal_plans p
        join public.plan_meals m on m.plan_id = p.id
       where p.conversation_id = c.conversation_id
    ) as conversation_added_meal,
    exists (
      select 1
        from public.meal_plans p
       where p.conversation_id = c.conversation_id
         and p.status = 'confirmed'
    ) as conversation_confirmed_plan
  from public.vana_calls c;

comment on view public.vana_call_facts is
  'One row per logged AI call with its plan label and the two conversation facts the weekly figures turn on (ai-cost ticket 05). vana_weekly_cost aggregates this.';

-- ---------------------------------------------------------------------------
-- 4 · THE saved weekly view — the five figures (mp-470 criterion 3)
-- ---------------------------------------------------------------------------
create or replace view public.vana_weekly_cost
with (security_invoker = true) as
with per_call as (select * from public.vana_call_facts),
weeks as (
  select
    week_start,
    plan,
    count(*)                                            as calls,
    count(gateway_cost_usd)                             as costed_calls,
    count(distinct user_id)                             as athletes,
    sum(coalesce(gateway_cost_usd, 0))                  as cost_usd,
    -- (b) first-step cache hit rate: cached prompt tokens over prompt tokens, on the first step only.
    sum(coalesce(first_step_cache_read_tokens, 0))      as first_step_cache_read_tokens,
    sum(coalesce(first_step_input_tokens, 0))           as first_step_input_tokens,
    sum(coalesce(cache_write_tokens, 0))                as cache_write_tokens,
    sum(coalesce(input_tokens, 0))                      as input_tokens,
    sum(coalesce(output_tokens, 0))                     as output_tokens,
    -- (c) cost per confirmed plan.
    sum(case when conversation_confirmed_plan then coalesce(gateway_cost_usd, 0) else 0 end)
                                                        as cost_in_confirmed_conversations_usd,
    count(distinct case when conversation_confirmed_plan then conversation_id end)
                                                        as confirmed_plan_conversations,
    -- (d) spend in planning conversations that never add a meal.
    sum(case when is_planning and conversation_id is not null and not conversation_added_meal
             then coalesce(gateway_cost_usd, 0) else 0 end)
                                                        as planning_cost_without_a_meal_usd,
    sum(case when is_planning and conversation_id is not null then coalesce(gateway_cost_usd, 0) else 0 end)
                                                        as planning_cost_usd,
    -- (e) share of turns that were fixed-label taps. Denominator: the turns the athlete sent (input_mode is set),
    -- which is the only population where "tap instead of typed" is a choice that was made.
    count(*) filter (where input_mode = 'tap')          as tapped_turns,
    count(*) filter (where input_mode is not null)      as athlete_turns,
    count(*) filter (where debited)                     as debited_calls
  from per_call
  group by week_start, plan
)
select
  week_start,
  plan,
  athletes,
  calls,
  costed_calls,
  debited_calls,
  round(cost_usd, 6)                                                            as cost_usd,
  -- (a) cost per athlete by plan.
  case when athletes > 0 then round(cost_usd / athletes, 6) end                 as cost_per_athlete_usd,
  -- (b)
  case when first_step_input_tokens > 0
       then round(first_step_cache_read_tokens::numeric / first_step_input_tokens, 4) end
                                                                               as first_step_cache_hit_rate,
  -- (c)
  case when confirmed_plan_conversations > 0
       then round(cost_in_confirmed_conversations_usd / confirmed_plan_conversations, 6) end
                                                                               as cost_per_confirmed_plan_usd,
  confirmed_plan_conversations,
  -- (d)
  round(planning_cost_without_a_meal_usd, 6)                                   as planning_cost_without_a_meal_usd,
  case when planning_cost_usd > 0
       then round(planning_cost_without_a_meal_usd / planning_cost_usd, 4) end as planning_spend_share_without_a_meal,
  -- (e)
  case when athlete_turns > 0 then round(tapped_turns::numeric / athlete_turns, 4) end
                                                                               as tapped_turn_share,
  tapped_turns,
  athlete_turns,
  input_tokens,
  output_tokens,
  cache_write_tokens,
  first_step_cache_read_tokens,
  first_step_input_tokens
from weeks
order by week_start desc, plan;

comment on view public.vana_weekly_cost is
  'THE saved weekly view (ai-cost ticket 05, mp-470 criterion 3): per ISO week and plan — cost per athlete, the first-step cache hit rate, cost per confirmed plan, planning spend in conversations that never add a meal, and the share of turns that were fixed-label taps. costed_calls vs calls says how much of the week actually carries a gateway charge.';

revoke all on public.vana_call_facts from anon;
revoke all on public.vana_weekly_cost from anon;
grant select on public.vana_call_facts, public.vana_weekly_cost to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5 · The weekly rollup the sweep keeps
-- ---------------------------------------------------------------------------
-- `vana_weekly_cost` reads raw rows, and the raw rows die at 90 days. The
-- rollup is the same figures frozen per week, written before the delete, so
-- the history that sets next year's numbers outlives its own rows.
create table if not exists public.vana_weekly_rollup (
  week_start                            date not null,
  plan                                  text not null,
  athletes                              integer not null,
  calls                                 integer not null,
  costed_calls                          integer not null,
  debited_calls                         integer not null,
  cost_usd                              numeric not null,
  cost_per_athlete_usd                  numeric,
  first_step_cache_hit_rate             numeric,
  cost_per_confirmed_plan_usd           numeric,
  confirmed_plan_conversations          integer not null,
  planning_cost_without_a_meal_usd      numeric not null,
  planning_spend_share_without_a_meal   numeric,
  tapped_turn_share                     numeric,
  tapped_turns                          integer not null,
  athlete_turns                         integer not null,
  input_tokens                          bigint not null,
  output_tokens                         bigint not null,
  cache_write_tokens                    bigint not null,
  first_step_cache_read_tokens          bigint not null,
  first_step_input_tokens               bigint not null,
  rolled_up_at                          timestamptz not null default now(),
  primary key (week_start, plan)
);

comment on table public.vana_weekly_rollup is
  'vana_weekly_cost frozen per week, written by ai_log_retention_sweep before the 90-day delete (ai-cost ticket 05). Rollups are kept; raw rows are not.';

alter table public.vana_weekly_rollup enable row level security;
drop policy if exists "vana_weekly_rollup_service_all" on public.vana_weekly_rollup;
create policy "vana_weekly_rollup_service_all" on public.vana_weekly_rollup for all
  using ((select auth.role()) = 'service_role');
revoke all on public.vana_weekly_rollup from anon, authenticated, public;
grant all on public.vana_weekly_rollup to service_role;

-- Re-roll every week that still has raw rows, up to (not including) the week
-- `p_now` falls in: the current week is still moving. Idempotent — a week
-- rolled up twice is overwritten with the same answer.
create or replace function public.vana_roll_up_weeks(p_now timestamptz)
returns integer
language plpgsql
set search_path = public
as $$
declare
  v_rows integer;
begin
  insert into public.vana_weekly_rollup as r (
    week_start, plan, athletes, calls, costed_calls, debited_calls, cost_usd, cost_per_athlete_usd,
    first_step_cache_hit_rate, cost_per_confirmed_plan_usd, confirmed_plan_conversations,
    planning_cost_without_a_meal_usd, planning_spend_share_without_a_meal, tapped_turn_share,
    tapped_turns, athlete_turns, input_tokens, output_tokens, cache_write_tokens,
    first_step_cache_read_tokens, first_step_input_tokens, rolled_up_at)
  select w.week_start, w.plan, w.athletes, w.calls, w.costed_calls, w.debited_calls, w.cost_usd,
         w.cost_per_athlete_usd, w.first_step_cache_hit_rate, w.cost_per_confirmed_plan_usd,
         w.confirmed_plan_conversations, w.planning_cost_without_a_meal_usd,
         w.planning_spend_share_without_a_meal, w.tapped_turn_share, w.tapped_turns, w.athlete_turns,
         w.input_tokens, w.output_tokens, w.cache_write_tokens, w.first_step_cache_read_tokens,
         w.first_step_input_tokens, p_now
    from public.vana_weekly_cost w
   where w.week_start < date_trunc('week', p_now)::date
  on conflict (week_start, plan) do update set
    athletes = excluded.athletes, calls = excluded.calls, costed_calls = excluded.costed_calls,
    debited_calls = excluded.debited_calls, cost_usd = excluded.cost_usd,
    cost_per_athlete_usd = excluded.cost_per_athlete_usd,
    first_step_cache_hit_rate = excluded.first_step_cache_hit_rate,
    cost_per_confirmed_plan_usd = excluded.cost_per_confirmed_plan_usd,
    confirmed_plan_conversations = excluded.confirmed_plan_conversations,
    planning_cost_without_a_meal_usd = excluded.planning_cost_without_a_meal_usd,
    planning_spend_share_without_a_meal = excluded.planning_spend_share_without_a_meal,
    tapped_turn_share = excluded.tapped_turn_share, tapped_turns = excluded.tapped_turns,
    athlete_turns = excluded.athlete_turns, input_tokens = excluded.input_tokens,
    output_tokens = excluded.output_tokens, cache_write_tokens = excluded.cache_write_tokens,
    first_step_cache_read_tokens = excluded.first_step_cache_read_tokens,
    first_step_input_tokens = excluded.first_step_input_tokens,
    rolled_up_at = p_now;
  get diagnostics v_rows = row_count;
  return v_rows;
end $$;

revoke execute on function public.vana_roll_up_weeks(timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6 · The 90-day sweep over the three AI log tables
-- ---------------------------------------------------------------------------
-- The same shape as `raw_retention_sweep` (2026-09-20): `p_now` is INJECTED so
-- a test can run it at any clock, and the cron entry is the only place the
-- wall clock enters. Boundary convention matches that sweep — STRICTLY older
-- than 90 days goes, a row exactly 90.0 days old is retained.
-- The rollup is written FIRST. A sweep that deleted before rolling up would
-- lose the week it was deleting.
create or replace function public.ai_log_retention_sweep(p_now timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_cutoff timestamptz := p_now - interval '90 days';
  v_rolled integer;   -- rollup ROWS (week × plan), not weeks
  v_calls bigint;
  v_usage bigint;
  v_plan_log bigint;
begin
  v_rolled := public.vana_roll_up_weeks(p_now);

  delete from public.vana_calls where created_at < v_cutoff;
  get diagnostics v_calls = row_count;
  delete from public.ai_usage where created_at < v_cutoff;
  get diagnostics v_usage = row_count;
  delete from public.plan_generation_log where created_at < v_cutoff;
  get diagnostics v_plan_log = row_count;

  return jsonb_build_object(
    'swept_at', p_now,
    'cutoff', v_cutoff,
    'rollup_rows_written', v_rolled,
    'purged', jsonb_build_object('vana_calls', v_calls, 'ai_usage', v_usage, 'plan_generation_log', v_plan_log),
    'rollup_rows_kept', (select count(*) from public.vana_weekly_rollup)
  );
end $$;

revoke execute on function public.ai_log_retention_sweep(timestamptz) from public, anon, authenticated;

comment on function public.ai_log_retention_sweep(timestamptz) is
  'Rolls up every complete week, then deletes rows strictly older than 90 days from vana_calls, ai_usage and plan_generation_log (ai-cost ticket 05). Rollups are kept. p_now is injected so a test can run it at any clock.';

-- ---------------------------------------------------------------------------
-- 7 · The daily cost alert — reports, refuses nothing
-- ---------------------------------------------------------------------------
-- "Refuses nothing" is the whole posture: this function only reads. There is
-- no branch here that can stop a call, and no caller of it on any request
-- path. The monthly budget is the thing that refuses (mp-430, ticket 09); this
-- is the thing that tells Lee the same day.
create or replace function public.vana_daily_cost_offenders(
  p_day        date,
  p_threshold  numeric default 1.50
) returns table (user_id uuid, day date, cost_usd numeric, calls bigint, costed_calls bigint)
language sql stable
set search_path = public
as $$
  select f.user_id,
         p_day,
         round(sum(coalesce(f.gateway_cost_usd, 0)), 6) as cost_usd,
         count(*)                                       as calls,
         count(f.gateway_cost_usd)                      as costed_calls
    from public.vana_call_facts f
   where f.call_day = p_day
   group by f.user_id
  having sum(coalesce(f.gateway_cost_usd, 0)) > p_threshold
   order by 3 desc
$$;

revoke execute on function public.vana_daily_cost_offenders(date, numeric) from public, anon, authenticated;

comment on function public.vana_daily_cost_offenders(date, numeric) is
  'Accounts whose logged gateway charge for p_day is over p_threshold dollars (ai-cost ticket 05, default $1.50). Read-only: it reports and refuses nothing.';

-- pg_net + Vault + an edge function, the same wiring the raw-retention alert
-- uses (20260920180000). Outbound HTTP from SQL stays service-side.
create extension if not exists pg_net;
revoke all on all functions in schema net from public, anon, authenticated;

-- Vault secrets (seed per env, never in a migration):
--   ai_cost_alert_url    https://<ref>.supabase.co/functions/v1/ai-cost-alert
--   ai_cost_alert_token  shared secret; must equal the function's AI_COST_ALERT_TOKEN secret
-- With them absent the check still runs and logs one NOTICE instead of reporting.
create or replace function public.vana_daily_cost_alert(
  p_day        date default null,
  p_threshold  numeric default 1.50
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_day date := coalesce(p_day, (now() at time zone 'UTC')::date - 1);
  v_offenders jsonb;
  v_url text;
  v_token text;
begin
  select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb) into v_offenders
    from public.vana_daily_cost_offenders(v_day, p_threshold) o;

  if jsonb_array_length(v_offenders) > 0 then
    select decrypted_secret into v_url   from vault.decrypted_secrets where name = 'ai_cost_alert_url';
    select decrypted_secret into v_token from vault.decrypted_secrets where name = 'ai_cost_alert_token';
    if v_url is null or v_token is null then
      raise notice 'ai-cost daily alert fired for % (% account(s) over $%) but the vault secrets are not seeded — Sentry report skipped',
        v_day, jsonb_array_length(v_offenders), p_threshold;
    else
      perform net.http_post(
        url := v_url,
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-alert-token', v_token),
        body := jsonb_build_object('day', v_day, 'threshold_usd', p_threshold, 'accounts', v_offenders)
      );
    end if;
  end if;

  return jsonb_build_object('day', v_day, 'threshold_usd', p_threshold, 'accounts', v_offenders);
end $$;

revoke execute on function public.vana_daily_cost_alert(date, numeric) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8 · Schedules. Idempotent via unschedule-if-exists, the pattern the
--     raw-retention sweep set. Both off the top of the hour.
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'ai-log-retention-sweep') then
    perform cron.unschedule('ai-log-retention-sweep');
  end if;
  perform cron.schedule(
    'ai-log-retention-sweep',
    '41 3 * * *',  -- daily 03:41 UTC, after the raw-retention sweep at 03:17
    $job$ select public.ai_log_retention_sweep(now()); $job$
  );

  if exists (select 1 from cron.job where jobname = 'ai-cost-daily-alert') then
    perform cron.unschedule('ai-cost-daily-alert');
  end if;
  perform cron.schedule(
    'ai-cost-daily-alert',
    '23 6 * * *',  -- daily 06:23 UTC: yesterday is complete in every timezone we bill in
    $job$ select public.vana_daily_cost_alert(); $job$
  );
end $$;
