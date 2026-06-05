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
--   • Section 4 (personal_formulas table) — DEV: apply now. PROD: with the
--     PR 5 release branch. New table; additive, no impact on existing clients.
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


-- ── 4. Create personal_formulas table (Formula Kit PR 5) ────────────────────
-- DEV: apply now. PROD: with the PR 5 release branch.
--
-- A personal formula is a user's edited/forked copy of a system Before/During
-- formula (the "Make this mine" save from formula_detail_screen). Distinct from
-- the legacy `personal_templates` table, which stores whole nutrition-plan
-- snapshots (plan_data JSON, activity context) — that table is being frozen +
-- its UI deprecated in PR 5d. See docs/features/formula-kit/PLAN.md (PR 5).
--
-- `components` is a JSON array of the edited components, each carrying food
-- identity + per-serving macros + quantity, e.g.
--   [{"food_key":"medjool_dates","user_food_id":null,"display_name":"Medjool Dates",
--     "serving_unit":null,"quantity":2.0,"carbs_per_serving":18,"protein_per_serving":0.4,
--     "fat_per_serving":0.1,"sodium_mg_per_serving":0,"fluid_ml_per_serving":0}]
-- `user_food_id` references user_foods.id when a component was swapped to a
-- user-created food (PR 5b); null for stock template foods.
--
-- Idempotent: safe to paste into DataGrip and re-run against dev or prod.

CREATE TABLE IF NOT EXISTS public.personal_formulas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,

  -- 'before' | 'during'. After-phase has no edit state (standard portion only).
  phase TEXT NOT NULL CHECK (phase IN ('before', 'during')),

  -- Provenance: the system template this was forked from (nullable for a
  -- from-scratch formula). Intentionally text, not FK — the source may live in
  -- pre_workout_templates or during_workout_templates.
  source_template_id UUID,

  -- Before-phase context (null for during). Values mirror
  -- BeforeSubPhase.storageValue (full_meal | snack | top_up).
  sub_phase TEXT CHECK (sub_phase IS NULL OR sub_phase IN ('full_meal', 'snack', 'top_up')),
  digestion_speed TEXT,
  template_type TEXT,

  -- During-phase context (null for before). text[] mirrors the catalog shape.
  activity_types TEXT[],
  duration_brackets TEXT[],
  gut_training_levels TEXT[],

  -- Edited components (see header). JSONB for query flexibility later.
  components JSONB NOT NULL DEFAULT '[]'::jsonb,

  -- Denormalized macro totals for list display without re-summing components.
  total_carbs_g NUMERIC NOT NULL DEFAULT 0,
  total_protein_g NUMERIC NOT NULL DEFAULT 0,
  total_fat_g NUMERIC NOT NULL DEFAULT 0,
  total_sodium_mg NUMERIC NOT NULL DEFAULT 0,
  total_fluid_ml NUMERIC NOT NULL DEFAULT 0,
  total_calories INT NOT NULL DEFAULT 0,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Soft delete (matches user_foods / formula_pins convention). Deleting a
  -- personal formula sets is_deleted=true so the change propagates across
  -- devices via the upsert-only sync handler. All reads filter NOT is_deleted.
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- Library reads personal formulas by (user, phase); indexed for the hot path.
CREATE INDEX IF NOT EXISTS personal_formulas_user_phase
  ON public.personal_formulas (user_id, phase)
  WHERE NOT is_deleted;

ALTER TABLE public.personal_formulas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own personal formulas" ON public.personal_formulas;
CREATE POLICY "Users manage own personal formulas"
  ON public.personal_formulas FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- updated_at trigger (matches existing convention).
CREATE OR REPLACE FUNCTION personal_formulas_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS personal_formulas_updated_at_trigger ON public.personal_formulas;
CREATE TRIGGER personal_formulas_updated_at_trigger
  BEFORE UPDATE ON public.personal_formulas
  FOR EACH ROW EXECUTE FUNCTION personal_formulas_set_updated_at();


-- ============================================================================
-- END
-- ============================================================================
