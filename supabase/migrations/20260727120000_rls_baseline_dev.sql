-- ============================================================================
-- RLS baseline — DEV
-- ============================================================================
-- Goal: every public table is row-level-secured, without breaking the app or
-- any edge function.
--
-- WHAT THE AUDIT FOUND (dev, 2026-07-27)
--
-- 1. 17 public tables had RLS disabled entirely — including `users` (248 rows),
--    `activities` (1128), `food_preferences` (3407) and `events`. Anyone with
--    the anon key could read every user's data.
--
-- 2. `activities`, `events`, `carb_loading_plans`, `carb_loading_days` and
--    `carb_loading_day_meals` already carried policies — but every one of them
--    keys off `current_setting('app.user_id', true)::uuid`, a session GUC that
--    nothing in this codebase ever sets (confirmed: no set_config anywhere in
--    lib/ or supabase/functions/, and supabase/prod_parity/01c_coach_rls_policies.sql
--    carries the same warning). Enabling RLS with those policies in place would
--    evaluate `user_id = NULL` for every request and silently return zero rows —
--    a total client blackout. They are dropped and rebuilt on auth.uid() here.
--    THIS IS THE STEP THAT MAKES ENABLING RLS SAFE RATHER THAN CATASTROPHIC.
--
-- 3. Edge functions are unaffected: 20 of them build a service-role client,
--    which bypasses RLS by design. Only `get-foods`, `search-catalog` and
--    `sync-all-data` use the anon key, and all three forward the caller's
--    Authorization header — so they act as that user and are covered by the
--    per-user policies below. `foods` gets an authenticated-read policy so
--    get-foods keeps working.
--
-- 4. Identity model: public.users.id IS the auth uid for every user created
--    since 2025-12-17 (anonymous auth). 136 legacy device-only rows (created
--    2025-11-13 … 2025-12-17, no auth.users row) predate that and will no
--    longer be readable from the client. They are dead dev data; the live app
--    has not created a device-only user in seven months. VERIFY THIS SAME
--    QUERY ON PROD BEFORE APPLYING THERE — see docs/database/rls-strategy.md.
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Helper — "am I an active coach for this athlete?"
-- ---------------------------------------------------------------------------
-- Coach mode legitimately reads and writes its athletes' rows. The old
-- policies inlined this EXISTS four times per table; a SECURITY DEFINER
-- function keeps the policies readable and, critically, stops the
-- coach_athlete_relationships lookup from recursing into that table's own RLS.
create or replace function public.is_active_coach_for(athlete uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.coach_athlete_relationships r
    where r.coach_user_id = auth.uid()
      and r.athlete_user_id = athlete
      and r.status = 'active'
  );
$$;

grant execute on function public.is_active_coach_for(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- 1. activities / events — drop the dead app.user_id policies, rebuild on
--    auth.uid(), then enable RLS.
-- ---------------------------------------------------------------------------
drop policy if exists activities_select_policy on public.activities;
drop policy if exists activities_insert_policy on public.activities;
drop policy if exists activities_update_policy on public.activities;
drop policy if exists activities_delete_policy on public.activities;

create policy activities_select on public.activities
  for select using (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
create policy activities_insert on public.activities
  for insert with check (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
create policy activities_update on public.activities
  for update using (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  ) with check (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
-- Delete stays owner-only, matching the old policy: a coach may schedule and
-- edit an athlete's work but not destroy their history.
create policy activities_delete on public.activities
  for delete using (user_id = auth.uid());

alter table public.activities enable row level security;

drop policy if exists events_select_policy on public.events;
drop policy if exists events_insert_policy on public.events;
drop policy if exists events_update_policy on public.events;
drop policy if exists events_delete_policy on public.events;

create policy events_select on public.events
  for select using (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
create policy events_insert on public.events
  for insert with check (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
create policy events_update on public.events
  for update using (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  ) with check (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
create policy events_delete on public.events
  for delete using (user_id = auth.uid());

alter table public.events enable row level security;

-- ---------------------------------------------------------------------------
-- 2. carb loading — same treatment; days/day_meals reach the owner through
--    their parent plan.
-- ---------------------------------------------------------------------------
drop policy if exists carb_plans_select_policy on public.carb_loading_plans;
drop policy if exists carb_plans_insert_policy on public.carb_loading_plans;
drop policy if exists carb_plans_update_policy on public.carb_loading_plans;
drop policy if exists carb_plans_delete_policy on public.carb_loading_plans;

create policy carb_plans_select on public.carb_loading_plans
  for select using (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
create policy carb_plans_insert on public.carb_loading_plans
  for insert with check (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
create policy carb_plans_update on public.carb_loading_plans
  for update using (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  ) with check (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
create policy carb_plans_delete on public.carb_loading_plans
  for delete using (user_id = auth.uid());

alter table public.carb_loading_plans enable row level security;

drop policy if exists carb_days_select_policy on public.carb_loading_days;
drop policy if exists carb_days_insert_policy on public.carb_loading_days;
drop policy if exists carb_days_update_policy on public.carb_loading_days;
drop policy if exists carb_days_delete_policy on public.carb_loading_days;

create policy carb_days_all on public.carb_loading_days
  for all using (
    exists (
      select 1 from public.carb_loading_plans p
      where p.id = carb_loading_days.carb_loading_plan_id
        and (p.user_id = auth.uid() or public.is_active_coach_for(p.user_id))
    )
  ) with check (
    exists (
      select 1 from public.carb_loading_plans p
      where p.id = carb_loading_days.carb_loading_plan_id
        and (p.user_id = auth.uid() or public.is_active_coach_for(p.user_id))
    )
  );

alter table public.carb_loading_days enable row level security;

drop policy if exists carb_meals_select_policy on public.carb_loading_day_meals;
drop policy if exists carb_meals_insert_policy on public.carb_loading_day_meals;
drop policy if exists carb_meals_update_policy on public.carb_loading_day_meals;
drop policy if exists carb_meals_delete_policy on public.carb_loading_day_meals;

create policy carb_meals_all on public.carb_loading_day_meals
  for all using (
    exists (
      select 1
      from public.carb_loading_days d
      join public.carb_loading_plans p on p.id = d.carb_loading_plan_id
      where d.id = carb_loading_day_meals.carb_loading_day_id
        and (p.user_id = auth.uid() or public.is_active_coach_for(p.user_id))
    )
  ) with check (
    exists (
      select 1
      from public.carb_loading_days d
      join public.carb_loading_plans p on p.id = d.carb_loading_plan_id
      where d.id = carb_loading_day_meals.carb_loading_day_id
        and (p.user_id = auth.uid() or public.is_active_coach_for(p.user_id))
    )
  );

alter table public.carb_loading_day_meals enable row level security;

-- ---------------------------------------------------------------------------
-- 3. Tables that already carry a correct auth.uid() policy but had RLS off —
--    switching it on is the whole fix.
-- ---------------------------------------------------------------------------
alter table public.user_foods enable row level security;
alter table public.carb_loading_user_foods enable row level security;

-- ---------------------------------------------------------------------------
-- 4. Per-user tables with no policies at all.
-- ---------------------------------------------------------------------------
drop policy if exists food_preferences_own on public.food_preferences;
create policy food_preferences_own on public.food_preferences
  for all using (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  ) with check (
    user_id = auth.uid() or public.is_active_coach_for(user_id)
  );
alter table public.food_preferences enable row level security;

-- `users`: public.users.id IS the auth uid (see header note 4). A coach may
-- read the profiles of athletes they actively coach — that is what the coach
-- portal's athlete list renders — but may not write them.
drop policy if exists users_select_own on public.users;
drop policy if exists users_insert_own on public.users;
drop policy if exists users_update_own on public.users;
create policy users_select_own on public.users
  for select using (
    id = auth.uid() or public.is_active_coach_for(id)
  );
create policy users_insert_own on public.users
  for insert with check (id = auth.uid());
create policy users_update_own on public.users
  for update using (id = auth.uid()) with check (id = auth.uid());
-- No delete policy: account deletion runs through the `delete-user` edge
-- function on the service role.
alter table public.users enable row level security;

-- ---------------------------------------------------------------------------
-- 5. Shared reference data — readable by any caller, writable only by the
--    service role (the refresh/import jobs).
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'foods',                  -- read by the get-foods edge fn + client
    'carb_loading_foods',
    'pre_workout_templates',
    'public_events',
    'app_content'             -- content management system payloads
  ] loop
    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format(
      'create policy %I on public.%I for select using (true)', t || '_read', t
    );
    execute format('drop policy if exists %I on public.%I', t || '_write_service', t);
    execute format(
      'create policy %I on public.%I for all to service_role using (true) with check (true)',
      t || '_write_service', t
    );
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Server-only tables — no client ever touches these (verified: none appear
--    in any `.from('…')` call in lib/). RLS on with no permissive policy means
--    only the service role can reach them.
-- ---------------------------------------------------------------------------
alter table public.events_coverage enable row level security;
alter table public.events_refresh_runs enable row level security;
alter table public.feature_survey_responses enable row level security;

-- ---------------------------------------------------------------------------
-- 7. feedback — repair, not just secure.
-- ---------------------------------------------------------------------------
-- This table already had RLS enabled with ZERO policies, so every client
-- insert has been failing silently. It also has no owner column, so there was
-- no way to write a policy that let a user read their own submission back —
-- which `.insert().select()` in supabase_feedback_service.dart requires. Add
-- the owner column, then the two policies that make the existing client code
-- work again while keeping submissions private.
alter table public.feedback
  add column if not exists user_id uuid default auth.uid() references auth.users(id) on delete set null;

drop policy if exists feedback_insert_own on public.feedback;
drop policy if exists feedback_select_own on public.feedback;
create policy feedback_insert_own on public.feedback
  for insert with check (user_id = auth.uid());
create policy feedback_select_own on public.feedback
  for select using (user_id = auth.uid());
-- Aggregate reporting (getFeedbackStats / getAllFeedback) is an admin path and
-- stays service-role only, deliberately.
