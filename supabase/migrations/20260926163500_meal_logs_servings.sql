-- meal_logs.servings: how many servings the row holds (testing-wave 112-012,
-- Lee 2026-09-26: a Recent row keeps the meal's per-serving numbers, so
-- 1 serving always means the original amount).
--
-- A quick log or a Recent re-log made at 1.5 or 2 servings stores the count;
-- the row's items and totals stay the amount eaten. Recent divides them by
-- this column, so a re-log at 2 servings does not become the meal's new
-- 1-serving base. Every existing row was logged at one serving, which the
-- default records. The app sends the column only when it is not 1, so a
-- build reaching a project before this migration keeps uploading ordinary
-- logs and fails only the scaled ones until the column lands (PGRST204).
--
-- Local mirror: Drift schemaVersion 24 (`meal_logs.servings REAL NOT NULL
-- DEFAULT 1.0`). Bump app_config.current_schema_version to 24 when the
-- build carrying it ships.
--
-- Apply per supabase/migrations/README.md: by hand, dev first, prod under
-- the deploy-approval gate. Idempotent.

ALTER TABLE public.meal_logs
  ADD COLUMN IF NOT EXISTS servings numeric NOT NULL DEFAULT 1;

ALTER TABLE public.meal_logs
  DROP CONSTRAINT IF EXISTS meal_logs_servings_positive;

ALTER TABLE public.meal_logs
  ADD CONSTRAINT meal_logs_servings_positive CHECK (servings > 0);

COMMENT ON COLUMN public.meal_logs.servings IS
  'Servings the row was logged at (items and totals are already multiplied). '
  'Recent divides by it to show the per-serving base. Default 1.';
