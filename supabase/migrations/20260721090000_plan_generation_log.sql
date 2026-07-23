-- Plan-generation ledger (bug 3a3e3fdb follow-through, Xuan's analytics ask):
-- one row per generate-nutrition-plan-v3 request recording targets vs
-- delivered totals, the during-cascade path taken, shortfalls, and pin
-- decisions. Written by the edge function with the service role only.
--
-- Failure-rate query, for reference:
--   select count(*) filter (where shortfalls ? 'during')::float / count(*)
--   from plan_generation_log where created_at > now() - interval '7 days';

create table if not exists public.plan_generation_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  plan_id uuid,
  device_id text,
  activity_type text,
  duration_minutes integer,
  gut_training_level text,
  during_path text,
  targets jsonb,
  delivered jsonb,
  shortfalls jsonb,
  pin_decision jsonb,
  warnings jsonb
);

-- RLS on with no policies: anon/authenticated cannot read or write; the
-- service-role client used by edge functions bypasses RLS.
alter table public.plan_generation_log enable row level security;

create index if not exists plan_generation_log_created_at_idx
  on public.plan_generation_log (created_at desc);
create index if not exists plan_generation_log_device_id_idx
  on public.plan_generation_log (device_id);
