-- Day planner + plan history (dev, 2026-08-27). Idempotent.
alter table public.meal_plans add column if not exists days jsonb not null default '{}'::jsonb;
-- allow an archived plan to coexist with a fresh draft for the same week
alter table public.meal_plans drop constraint if exists meal_plans_user_id_week_start_key;
create unique index if not exists meal_plans_active_week on public.meal_plans (user_id, week_start) where status <> 'archived' and not is_deleted;
