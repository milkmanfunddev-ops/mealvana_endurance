-- ============================================================================
-- APPLY ALL — current PENDING SQL
--
-- The SINGLE file to paste into DataGrip and run, top to bottom.
-- Every statement is idempotent — safe to re-run.
--
-- ⚠️ PROD gating is PER-SECTION (read each section header):
--   • Section 1 (formula_pins.template_kind) — ✅ APPLIED to DEV + PROD on
--     2026-06-09 via `supabase db query --linked` (CHECK now includes
--     'personal_formula'; verified on both via pg_get_constraintdef). The
--     personal_formulas table was already present in both envs. No longer
--     pending — kept here only for idempotent re-runs.
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


-- ── 1. Widen formula_pins.template_kind (post_system + personal_formula) ─────
-- PR 3 (After-phase parity) added post-workout pins. The personalization PR
-- adds 'personal_formula' so user-authored rows in personal_formulas become
-- pinnable. The original CHECK only allowed pre_system / during_system; we
-- widen it here. Idempotent: drop-if-exists (by column) + add (named).
--
-- NOTE: the wire value is 'personal_formula' (matching the personal_formulas
-- table), NOT 'personal_template'.

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
    CHECK (template_kind IN
      ('pre_system', 'during_system', 'post_system', 'personal_formula'));

COMMENT ON COLUMN public.formula_pins.template_kind IS
  'Polymorphic ref into pre_workout_templates, during_workout_templates, '
  'post_workout_templates, or personal_formulas. Intentionally text, not FK. '
  'Widened to ''personal_formula'' when personal formulas became pinnable.';


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


-- ── 4. NEW TABLE: personal_formulas (Formula Kit personal formulas) ─────────
-- DEV: apply now. PROD: safe to apply now (new table, no dependents yet).
--
-- Personal formulas are user-owned, reusable fueling "recipes" tied to a
-- workout phase (before/during/after). They are a DISTINCT concept from
-- personal_templates (which stores saved nutrition-plan snapshots), so they
-- get their own table rather than overloading personal_templates with a
-- provenance discriminator. The personal_templates_formula_kit_columns
-- migration (20260522120100) is therefore NOT used by this design — its
-- columns are additive/harmless and left in place.
--
-- Provenance here only ever describes how the FORMULA was authored:
--   • forked_formula      — copied from a system formula ("Make this mine")
--                           → must carry source_template_id + source_template_kind
--   • from_scratch_formula — built from a blank slate
-- (No 'legacy_plan' value — that concept stays in personal_templates.)
--
-- Soft-deleted via is_deleted so (a) unpin/delete propagates across devices
-- through upsert-only sync and (b) formula_pins rows referencing a deleted
-- formula can be cleaned up at the app layer (PR 5). Mirrors the formula_pins
-- + user_foods soft-delete convention.
--
-- Idempotent: CREATE TABLE IF NOT EXISTS + guarded constraint/index/trigger.

CREATE TABLE IF NOT EXISTS public.personal_formulas (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,

  -- How the formula was authored.
  provenance    TEXT NOT NULL
                  CHECK (provenance IN ('forked_formula', 'from_scratch_formula')),

  -- Which phase of the workout this formula fuels.
  phase         TEXT NOT NULL CHECK (phase IN ('before', 'during', 'after')),

  -- Forked-only provenance: the system template this was copied from.
  -- Polymorphic (no FK) — source_template_kind disambiguates which catalog.
  source_template_id   UUID,
  source_template_kind TEXT
                  CHECK (source_template_kind IS NULL
                         OR source_template_kind IN
                            ('pre_system', 'during_system', 'post_system')),

  -- Phase-specific scope metadata (all nullable; only the relevant phase fills).
  sub_phase           TEXT,   -- before:  'full_meal' | 'snack' | 'top_up'
  digest_speed        TEXT,   -- before:  'fast' | 'medium'
  activities          JSONB,  -- during/after: array of activity types
  durations           JSONB,  -- during:  array of duration brackets
  gut_training        TEXT,   -- during:  gut-training level
  travel_friendliness TEXT,   -- after:   'in_bag' | 'cooler_friendly' | 'home_only'

  -- The formula body: array of component objects
  -- ({ food_name, quantity, unit, source, user_food_id? }). Shape is finalized
  -- by the PR 4 edit UI; stored opaque here.
  components    JSONB NOT NULL DEFAULT '[]'::jsonb,

  notes         TEXT,

  -- Denormalized macro totals for list/detail display (recomputed on save).
  total_carbs_g   INT,
  total_protein_g INT,
  total_fat_g     INT,
  total_sodium_mg INT,
  total_fluids_ml INT,
  total_calories  INT,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted    BOOLEAN NOT NULL DEFAULT false
);

-- Provenance integrity: a forked formula must point at its source template.
ALTER TABLE public.personal_formulas
  DROP CONSTRAINT IF EXISTS personal_formulas_forked_source_check;
ALTER TABLE public.personal_formulas
  ADD CONSTRAINT personal_formulas_forked_source_check
    CHECK (
      provenance <> 'forked_formula'
      OR (source_template_id IS NOT NULL AND source_template_kind IS NOT NULL)
    );

-- "Your formulas" listing: active rows by user + phase.
CREATE INDEX IF NOT EXISTS personal_formulas_user_phase
  ON public.personal_formulas (user_id, phase)
  WHERE NOT is_deleted;

ALTER TABLE public.personal_formulas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own formulas" ON public.personal_formulas;
CREATE POLICY "Users manage own formulas"
  ON public.personal_formulas FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- updated_at trigger (reuses the formula_pins convention; standalone function
-- so this table is self-contained).
CREATE OR REPLACE FUNCTION public.personal_formulas_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS personal_formulas_updated_at_trigger ON public.personal_formulas;
CREATE TRIGGER personal_formulas_updated_at_trigger
  BEFORE UPDATE ON public.personal_formulas
  FOR EACH ROW EXECUTE FUNCTION public.personal_formulas_set_updated_at();


-- ============================================================================
-- END
-- ============================================================================
