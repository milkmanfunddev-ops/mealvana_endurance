-- The Simulated athlete and the seed Scenarios (eval-v2 ticket 05). DEV ONLY, like 20260928160000_eval_schema.sql:
-- the eval system (../mealvana_eval) runs against dev Supabase and never prod. Leave this file loose; do not add it
-- to a prod cutover.
--
-- eval.scenarios.notes: what the Judge reads beside the goal (required beats, Examiner notes, setup, the account the
-- Scenario was written for). The Simulated athlete does not see it. The 22 seed Scenarios come from eval/scenarios/
-- (scripts/seed-scenarios.ts in ../mealvana_eval).
--
-- eval.runs.athlete: each Simulated athlete call of a simulated Run, in order: {turn, goal_met, message, reasoning,
-- model, cost, generation_id}. turn is the turn its message opened, or null when it said its goal was met. Its cost
-- also goes in eval.runs.cost as {athlete}.
--
-- Idempotent.

alter table eval.scenarios add column if not exists notes text not null default '';

alter table eval.runs add column if not exists athlete jsonb not null default '[]'::jsonb;
alter table eval.runs drop constraint if exists runs_athlete_array;
alter table eval.runs add constraint runs_athlete_array check (jsonb_typeof(athlete) = 'array');
