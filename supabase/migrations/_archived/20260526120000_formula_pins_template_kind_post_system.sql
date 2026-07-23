-- ============================================================================
-- APPLY ALL — current PENDING SQL
--
-- The SINGLE file to paste into DataGrip and run, top to bottom.
-- Every statement is idempotent — safe to re-run.
--
-- DEV: apply now.
-- PROD: DO NOT apply yet — gated on PR 3 substep 1 (TemplateKind crash-safety)
--       shipping to the App Store via a release branch. See
--       docs/features/formula-kit/PLAN.md "PR 3 substep 2" + "substep 12"
--       for the prod rollout sequencing.
--
-- After applying:
--   1. Save a dated copy at supabase/migrations/_archived/<YYYYMMDDhhmmss>_<slug>.sql
--   2. Clear this file for the next change.
-- ============================================================================


-- ── 1. Widen formula_pins.template_kind to include 'post_system' ────────────
-- PR 3 (After-phase parity) adds post-workout pins. The original CHECK
-- constraint only allowed pre_system / during_system; we widen it here.
-- Idempotent: drop-if-exists + add. The constraint is unnamed in the
-- original migration, so we find it by column.

DO $$
DECLARE
  constraint_name TEXT;
BEGIN
  SELECT con.conname INTO constraint_name
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
  WHERE nsp.nspname = 'public'
    AND rel.relname = 'formula_pins'
    AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) ILIKE '%template_kind%';

  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.formula_pins DROP CONSTRAINT %I', constraint_name);
  END IF;
END $$;

ALTER TABLE public.formula_pins
  ADD CONSTRAINT formula_pins_template_kind_check
    CHECK (template_kind IN ('pre_system', 'during_system', 'post_system'));

COMMENT ON COLUMN public.formula_pins.template_kind IS
  'Polymorphic ref into pre_workout_templates, during_workout_templates, or '
  'post_workout_templates. Intentionally text, not FK. Widened to '
  '''personal_template'' in PR 5 when personal formulas become pinnable.';


-- ============================================================================
-- END
-- ============================================================================
