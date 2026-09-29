-- The Rubric and each Run's Mark (eval-v2 ticket 04). DEV ONLY, like 20260928160000_eval_schema.sql: the eval
-- system (../mealvana_eval) runs against dev Supabase and never prod. Leave this file loose; do not add it to a
-- prod cutover.
--
-- eval.rubric_versions holds every version of the Rubric; an edit is a new row, never an update. A Run records the
-- version it was Marked against. The web app seeds version 1 from eval/rubric.md (scripts/seed-rubric.ts in ../mealvana_eval).
--
-- A Run's Marking lives on eval.runs: the Tool expectation results code checked, the Judge's validated output, the
-- Mark code computed from it, and a judging error when the Judge failed or answered in the wrong shape (then there is
-- no Mark). A Run is 'judging' between its last turn and its Mark.
--
-- Admins only, as the rest of the schema. Timestamps are timestamptz. Idempotent.

create table if not exists eval.rubric_versions (
  id uuid primary key default gen_random_uuid(),
  version integer not null unique check (version > 0),
  -- {intro, dimensions: [{key, name, weight, description, anchors: {"0".."100"}}], robotic_cap: {cap, description},
  --  pass_bar: {run, round_average}}
  rubric jsonb not null,
  created_at timestamptz not null default now()
);

alter table eval.runs drop constraint if exists runs_status_check;
alter table eval.runs add constraint runs_status_check check (status in ('running', 'judging', 'completed', 'failed'));

alter table eval.runs
  add column if not exists rubric_version_id uuid references eval.rubric_versions (id) on delete restrict,
  add column if not exists expectations jsonb,
  add column if not exists judgement jsonb,
  add column if not exists judge_error text,
  add column if not exists mark numeric check (mark between 0 and 100),
  add column if not exists passed boolean,
  -- USD per model: {judge}; later {vana, athlete, judge}.
  add column if not exists cost jsonb not null default '{}'::jsonb;

grant select, insert, update, delete on eval.rubric_versions to authenticated, service_role;
revoke all on eval.rubric_versions from anon;

alter table eval.rubric_versions enable row level security;
drop policy if exists rubric_versions_admins on eval.rubric_versions;
create policy rubric_versions_admins on eval.rubric_versions for all to authenticated
  using (eval.is_admin()) with check (eval.is_admin());
