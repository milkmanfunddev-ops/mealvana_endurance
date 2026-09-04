-- Meal planning — the relationship loop (plan Phase 3, docs/new_mealplanning/vana-chatbot-update-plan.md §5).
-- Additive + idempotent. Server-only columns: the Flutter client never reads them (not on the MealPlan wire contract),
-- so no Drift schema bump. Prod: carry with the meal-planning cutover bundle (supabase/migrations/cutover/meal_planning/).

-- 1. Plan lifecycle stamps: when the check-in opener was shown, when the debrief was recorded.
alter table public.meal_plans add column if not exists checkin_done_at timestamptz;
alter table public.meal_plans add column if not exists debrief_done_at timestamptz;

-- 2. End-of-week debriefs — what actually happened, feeding the next proposal (context LAST WEEK line).
create table if not exists public.plan_debriefs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  plan_id     uuid not null references public.meal_plans(id) on delete cascade,
  completed   integer not null check (completed >= 0),
  planned     integer not null check (planned >= 0),
  skip_reason text,
  notes       text,
  created_at  timestamptz not null default now()
);
create index if not exists plan_debriefs_user_idx on public.plan_debriefs (user_id, created_at desc);
alter table public.plan_debriefs enable row level security;
drop policy if exists "plan_debriefs owner" on public.plan_debriefs;
create policy "plan_debriefs owner" on public.plan_debriefs for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
