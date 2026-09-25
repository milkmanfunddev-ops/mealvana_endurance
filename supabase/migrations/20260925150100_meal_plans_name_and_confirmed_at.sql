-- Plans are a list (mp-675, mp-677; testing-wave ticket 73, Finding 17-002).
--
-- 1. meal_plans.name: the athlete's own name for a plan ("rename" in Previous plans). null = the plan is shown by its week.
-- 2. meal_plans.confirmed_at: when the plan was first confirmed. Previous plans lists a plan that is confirmed or was once
--    (a plan a later plan replaced is archived with confirmed_at kept); a draft never confirmed is not listed, even when
--    another plan's confirm archived it. `status` alone cannot tell those two archived plans apart.
-- 3. confirm_meal_plan stamps confirmed_at (first confirm wins). Body otherwise unchanged from
--    20260902090000_meal_planning_rpcs.sql.
--
-- Backfill for plans confirmed before this column: a plan confirmed now; an archived plan whose shopping list was marked
-- confirmed (markListConfirmed, since 2026-09-16); an archived plan that had its check-in or debrief (only a confirmed
-- plan gets those). An archived plan confirmed before 2026-09-16 with neither leaves the list.
--
-- Idempotent: safe to re-run on dev and on prod at the meal-planning cutover. Apply BEFORE deploying vana-action /
-- vana-chat from ticket 73: listPlans selects both columns.

alter table public.meal_plans add column if not exists name text;
alter table public.meal_plans drop constraint if exists meal_plans_name_length_check;
alter table public.meal_plans add constraint meal_plans_name_length_check check (name is null or char_length(name) between 1 and 60);
comment on column public.meal_plans.name is
  'The athlete''s own name for the plan (rename in Previous plans, mp-675). null = shown by its week.';

alter table public.meal_plans add column if not exists confirmed_at timestamptz;
comment on column public.meal_plans.confirmed_at is
  'When the plan was first confirmed (confirm_meal_plan). Kept when a later plan archives it; Previous plans lists plans with it set (mp-677).';

update public.meal_plans set confirmed_at = updated_at
 where confirmed_at is null and status = 'confirmed';

update public.meal_plans p set confirmed_at = l.confirmed_at
  from public.shopping_lists l
 where p.confirmed_at is null and l.plan_id = p.id and l.confirmed_at is not null;

update public.meal_plans set confirmed_at = coalesce(checkin_done_at, debrief_done_at)
 where confirmed_at is null and (checkin_done_at is not null or debrief_done_at is not null);

create or replace function public.confirm_meal_plan(p_plan_id uuid, p_shopping jsonb default null)
returns public.meal_plans
language plpgsql volatile security invoker set search_path = public as $$
declare
  v_plan public.meal_plans;
begin
  select * into v_plan from public.meal_plans where id = p_plan_id and not is_deleted for update;
  if not found then raise exception 'plan not found: %', p_plan_id; end if;

  update public.meal_plans
     set status = 'archived', updated_at = now()
   where user_id = v_plan.user_id and week_start = v_plan.week_start
     and id <> p_plan_id and status <> 'archived' and not is_deleted;

  update public.meal_plans
     set status = 'confirmed',
         confirmed_at = coalesce(confirmed_at, now()),
         shopping = coalesce(p_shopping, shopping),
         day_notes_stale = true,
         updated_at = now()
   where id = p_plan_id
  returning * into v_plan;
  return v_plan;
end $$;
revoke all on function public.confirm_meal_plan(uuid, jsonb) from public;
grant execute on function public.confirm_meal_plan(uuid, jsonb) to authenticated, service_role;
