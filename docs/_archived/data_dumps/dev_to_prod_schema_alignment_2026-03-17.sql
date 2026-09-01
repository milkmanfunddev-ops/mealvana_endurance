-- Align dev schema to prod schema (source of truth)
-- Generated: 2026-03-17
-- Scope: remove objects present in dev but not in prod

BEGIN;

-- Present in dev only; not in prod schema dump.
DROP INDEX IF EXISTS public.idx_templates_food_names;

COMMIT;
