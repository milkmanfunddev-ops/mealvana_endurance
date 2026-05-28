-- ============================================================================
-- APPLY ALL — current PENDING SQL
--
-- The SINGLE file to paste into DataGrip and run, top to bottom.
-- Every statement is idempotent — safe to re-run.
--
-- ⚠️ PROD gating is PER-SECTION (read each section header):
--   • Section 1 (formula_pins.template_kind) — DEV: apply now. PROD: NOT yet,
--     gated on PR 3 substep 1 (TemplateKind crash-safety) shipping via a
--     release branch. See docs/features/formula-kit/PLAN.md "PR 3 substep 2"
--     + "substep 12".
--   • Section 2 (category_enum during_bike/during_swim) — DEV + PROD: safe to
--     apply now. Independent of formula-kit; fixes a live 22P02 error on every
--     cycling/swim plan generation.
--   • Section 3 (users sweat-profile columns) — DEV + PROD: safe to apply now.
--     Independent of formula-kit; fixes a live 42703 error that makes EVERY
--     profile save (name/allergies/diet) fail to reach Supabase.
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


-- ── 2. Add multi-sport "during" categories to category_enum ─────────────────
-- DEV + PROD: safe to apply now (independent of formula-kit).
--
-- Bug: generate-nutrition-plan-v3 throws
--   22P02 invalid input value for enum category_enum: "during_bike"
-- on every cycling (and swimming) plan. getCategoryForPhase('during','cycling')
-- in supabase/functions/_shared/nutrition/constants.ts returns
-- ['during_bike','during_run'], and the user_foods query filters
-- categories=ov.{during_bike,during_run}. category_enum currently only has
-- before_run/during_run/after_run/transition (verified on dev), so the cast
-- fails and the during-phase user-foods fetch errors out.
--
-- category_enum is shared by foods.categories and user_foods.categories (both
-- category_enum[]). template_foods.categories is text[], which is why that
-- table already tolerated during_bike — this aligns the enum-typed columns.
--
-- ADD VALUE IF NOT EXISTS is idempotent. In PG12+ it may run inside a
-- transaction as long as the new value is not USED in the same transaction
-- (it isn't here). If your client wraps the whole file in one transaction and
-- complains, run these two statements on their own.

ALTER TYPE public.category_enum ADD VALUE IF NOT EXISTS 'during_bike';
ALTER TYPE public.category_enum ADD VALUE IF NOT EXISTS 'during_swim';


-- ── 3. Add sweat-profile columns to public.users ────────────────────────────
-- DEV + PROD: safe to apply now (verified MISSING on both as of 2026-05-28).
--
-- Bug: UserProfile.toJson() (lib/features/auth/domain/user_preferences.dart)
-- sends sweat_sodium / known_sweat_rate_ml_per_hour /
-- known_sodium_concentration_mg_per_liter / sweat_test_date / sweat_test_source,
-- but these columns do not exist on the users table. So
-- supabase.from('users').upsert(profile.toJson()) fails with
--   42703 column users.sweat_sodium does not exist
-- on EVERY profile save — which means editing first/last name, allergies, or
-- dietary preference on the settings screen never reaches Supabase (the error
-- was swallowed and the record wasn't even marked dirty). This is the additive
-- migration 20260420200000_add_sweat_profile_fields.sql that was written but
-- never applied to dev/prod. Idempotent (ADD COLUMN IF NOT EXISTS).

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS sweat_sodium TEXT
    CHECK (sweat_sodium IN ('low', 'average', 'high', 'medium'));

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS known_sweat_rate_ml_per_hour INT;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS known_sodium_concentration_mg_per_liter INT;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS sweat_test_date TIMESTAMPTZ;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS sweat_test_source TEXT
    CHECK (sweat_test_source IN ('self_calculated', 'commercial_test', 'gatorade_gx', 'estimated', 'other'));


-- ============================================================================
-- END
-- ============================================================================
