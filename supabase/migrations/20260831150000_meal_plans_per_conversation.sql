-- Meal-plan drafts are per conversation (2026-08-31). One CONFIRMED plan per athlete-week; any number of drafts,
-- each owned by the Vana conversation that is building it. Idempotent.
alter table public.meal_plans add column if not exists conversation_id uuid references public.vana_conversations(id) on delete set null;
create index if not exists meal_plans_conversation_idx on public.meal_plans (conversation_id) where conversation_id is not null;
drop index if exists public.meal_plans_active_week;
create unique index if not exists meal_plans_confirmed_week on public.meal_plans (user_id, week_start) where status = 'confirmed' and not is_deleted;
