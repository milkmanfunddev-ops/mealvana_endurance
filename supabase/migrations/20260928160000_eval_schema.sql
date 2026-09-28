-- The eval system's own tables (eval-v2 ticket 03). DEV ONLY: the eval system (../mealvana_eval) runs against
-- dev Supabase and never prod, so this schema is never applied there. Leave this file loose; do not add it to a
-- prod cutover.
--
-- This is the first cut: Eval athletes, Scenarios, Runs, and each Run's turns and steps. Later tickets add the
-- Rubric, Marks, Eval rounds and Improvements in their own migrations.
--
-- Admins only. RLS is on for every table and the one policy per table lets a caller through only when
-- public.users.is_admin is true for auth.uid(). anon gets nothing. The web app reads and writes as an admin's
-- session, so these policies are what it runs under. The schema must also be in PostgREST's exposed schemas
-- (Management API /v1/projects/{ref}/postgrest, db_schema); that is project config, not SQL.
--
-- Timestamps are timestamptz. Idempotent.

create schema if not exists eval;

-- security definer: authenticated cannot select public.users.is_admin directly under every policy, and a
-- policy that reads public.users would also run public.users' own RLS.
create or replace function eval.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select u.is_admin from public.users u where u.id = auth.uid()), false);
$$;

revoke all on function eval.is_admin() from public, anon;
grant execute on function eval.is_admin() to authenticated, service_role;

-- An Eval athlete: a snapshot as vana-eval's `start` takes it, {user_id, tables: {<table>: rows}}, over the
-- tables in supabase/functions/vana-eval/copy.ts COPY_TABLES.
create table if not exists eval.athletes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source text not null default 'hand' check (source in ('hand', 'dev', 'prod')),
  source_user_id uuid,
  taken_at timestamptz not null default now(),
  snapshot jsonb not null,
  created_at timestamptz not null default now()
);

-- A Scenario. Scripted: the opening turn (or Vana's opener) then the fixed turns, in order. Simulated: the
-- opening turn, then the Simulated athlete up to turn_limit. chat_kind is the conversation kind runChat opens.
create table if not exists eval.scenarios (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null default 'simulated' check (kind in ('scripted', 'simulated')),
  chat_kind text not null default 'meal_planning' check (chat_kind in ('meal_planning', 'general')),
  goal text not null default '',
  persona text not null default '',
  opener boolean not null default false,
  opening_turn text,
  fixed_turns jsonb not null default '[]'::jsonb check (jsonb_typeof(fixed_turns) = 'array'),
  turn_limit integer not null default 8 check (turn_limit > 0),
  tool_expectations jsonb not null default '[]'::jsonb check (jsonb_typeof(tool_expectations) = 'array'),
  default_athlete_id uuid references eval.athletes (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A Run. Scenario and athlete may be deleted later; the Run keeps their names as it ran.
create table if not exists eval.runs (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid references eval.scenarios (id) on delete set null,
  athlete_id uuid references eval.athletes (id) on delete set null,
  scenario_name text not null,
  athlete_name text not null,
  status text not null default 'running' check (status in ('running', 'completed', 'failed')),
  error text,
  settings jsonb not null default '{}'::jsonb,
  run_user_id uuid,
  conversation_id uuid,
  before jsonb,
  after jsonb,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists runs_started_at on eval.runs (started_at desc);

-- One turn: what the athlete sent (or Vana's opener), Vana's reply as it streams, and the turn's trace without
-- its steps, which go to eval.steps.
create table if not exists eval.turns (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references eval.runs (id) on delete cascade,
  idx integer not null,
  opener boolean not null default false,
  athlete_message text,
  reply text not null default '',
  ui_parts jsonb not null default '[]'::jsonb,
  status text not null default 'streaming' check (status in ('streaming', 'done', 'failed')),
  error text,
  trace jsonb,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  unique (run_id, idx)
);

-- One model step of a turn, as vana-eval's trace line carries it: text, tool calls with inputs, tool results with
-- full outputs, tool errors, usage, generation id.
create table if not exists eval.steps (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references eval.runs (id) on delete cascade,
  turn_id uuid not null references eval.turns (id) on delete cascade,
  idx integer not null,
  payload jsonb not null,
  unique (turn_id, idx)
);

create index if not exists steps_run_id on eval.steps (run_id);

grant usage on schema eval to authenticated, service_role;
revoke all on all tables in schema eval from anon;
grant select, insert, update, delete on all tables in schema eval to authenticated, service_role;

do $$
declare t text;
begin
  foreach t in array array['athletes', 'scenarios', 'runs', 'turns', 'steps'] loop
    execute format('alter table eval.%I enable row level security', t);
    execute format('drop policy if exists %I on eval.%I', t || '_admins', t);
    execute format('create policy %I on eval.%I for all to authenticated using (eval.is_admin()) with check (eval.is_admin())', t || '_admins', t);
  end loop;
end $$;

comment on schema eval is 'The eval system (../mealvana_eval), eval-v2. Dev only. Admins only.';
