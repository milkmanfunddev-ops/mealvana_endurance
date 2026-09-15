-- Meal reviews and the admin flag (mealplanning ticket 25, mp-144 clause 3 / mp-303).
--
-- A signed-in admin sees a comment box under the thumbs on every meal page: is this a good
-- recipe, and why. Each comment lands here with the meal, the admin and the date, for the team
-- to read. Athletes never see the box.
--
-- Admin is a boolean on the user record, set by hand in the database (no admin UI grants it).
-- The server reads it for the insert policy; the client reads it (users_select_own covers the
-- own row) to decide whether to show the box.
--
-- Conventions: created_at is timestamptz (server clock), unlike the app's naive-local
-- scheduled_date_time columns. meal_id is the library id (D-048) or the saved-meal uuid, as a
-- string, with meal_source saying which — the same pair meal_feedback uses.
--
-- Idempotent. Apply to dev; prod follows the meal-planning cutover runbook.

alter table public.users add column if not exists is_admin boolean not null default false;
comment on column public.users.is_admin is
  'Team member who may review meals (meal_reviews insert policy). Set by hand in the database; no UI grants it.';

create table if not exists public.meal_reviews (
  id uuid primary key default gen_random_uuid(),
  reviewer_id uuid not null references auth.users(id) on delete cascade,
  meal_source text not null check (meal_source in ('library', 'saved')),
  meal_id text not null,
  meal_name text not null default '',
  is_good boolean not null,
  why text not null check (length(why) between 1 and 2000),
  app_version text null,
  created_at timestamptz not null default now()
);
comment on table public.meal_reviews is
  'An admin''s verdict on a meal: is it a good recipe and why. One row per comment; the team reads them here.';

create index if not exists meal_reviews_meal on public.meal_reviews (meal_source, meal_id, created_at desc);
create index if not exists meal_reviews_reviewer_created on public.meal_reviews (reviewer_id, created_at desc);

alter table public.meal_reviews enable row level security;
grant all on public.meal_reviews to service_role;
grant select, insert on public.meal_reviews to authenticated;

-- Insert: the signed-in user must be an admin and must sign the row as themselves.
drop policy if exists meal_reviews_insert_admin on public.meal_reviews;
create policy meal_reviews_insert_admin on public.meal_reviews
  for insert to authenticated
  with check (
    reviewer_id = auth.uid()
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.is_admin
    )
  );

-- Select: admins read every review (the team's reading surface); athletes read none.
drop policy if exists meal_reviews_select_admin on public.meal_reviews;
create policy meal_reviews_select_admin on public.meal_reviews
  for select to authenticated
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.is_admin
    )
  );
