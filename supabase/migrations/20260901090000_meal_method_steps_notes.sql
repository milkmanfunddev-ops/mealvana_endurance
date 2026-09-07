-- =====================================================================
-- 20260901_090000 · meal method steps + user directions on saved meals
-- Meals tab v2: recipe detail pages show "How to cook" steps; the athlete
-- can optionally store their own directions on a saved meal.
-- Idempotent — safe to re-run.
-- =====================================================================

-- Ordered cooking-method steps for kind='recipe' rows. Written by
-- scripts/backfill_recipe_steps.mjs from docs/new_mealplanning/recipe-steps.json
-- (AI-written from our own data: name + ingredients + prep + prep_minutes).
alter table public.meal_library add column if not exists method_steps jsonb not null default '[]'::jsonb;
comment on column public.meal_library.method_steps is 'Ordered array of cooking-method step strings; empty for assemblies (no method by definition).';

-- The athlete's own optional directions for one of their saved meals.
-- Distinct from meal_logs.notes, which is a note on a single log entry.
alter table public.saved_meals add column if not exists notes text;
comment on column public.saved_meals.notes is 'Optional user-entered directions/notes for this saved meal (max ~2000 chars).';
