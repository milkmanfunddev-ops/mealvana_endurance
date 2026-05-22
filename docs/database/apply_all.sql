-- ============================================================================
-- APPLY ALL — pending Formula Kit / DB schema changes
--
-- This is the SINGLE file to paste into DataGrip and run, top to bottom,
-- against DEV and PROD. Every statement is idempotent — safe to re-run.
--
-- Contents:
--   1. formula_pins                         (PR 2 — pins; needed for pins to sync)
--   2. custom_foods                         (PR 4 prep — user-created foods)
--   3. personal_templates formula-kit cols  (PR 4 prep — additive, auto-backfilled)
--
-- These are additive and safe for old app versions (they SELECT * and ignore
-- unknown columns; they never reference custom_foods). Blocks 2 and 3 are
-- schema prep — no app code consumes them until the PR 4 wiring ships.
--
-- Per-change source files live in supabase/migrations/ for the repo record.
-- Last updated: 2026-05-22
-- ============================================================================


-- ============================================================================
-- 1. formula_pins  (PR 2)
-- ============================================================================
CREATE TABLE IF NOT EXISTS formula_pins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  template_id UUID NOT NULL,
  template_kind TEXT NOT NULL CHECK (template_kind IN ('pre_system', 'during_system')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE UNIQUE INDEX IF NOT EXISTS formula_pins_active_unique
  ON formula_pins (user_id, template_id, template_kind) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS formula_pins_user_kind
  ON formula_pins (user_id, template_kind) WHERE NOT is_deleted;

ALTER TABLE formula_pins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own pins" ON formula_pins;
CREATE POLICY "Users manage own pins"
  ON formula_pins FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION formula_pins_set_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS formula_pins_updated_at_trigger ON formula_pins;
CREATE TRIGGER formula_pins_updated_at_trigger
  BEFORE UPDATE ON formula_pins
  FOR EACH ROW EXECUTE FUNCTION formula_pins_set_updated_at();


-- ============================================================================
-- 2. custom_foods  (PR 4)
-- ============================================================================
CREATE TABLE IF NOT EXISTS custom_foods (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  serving_amount NUMERIC,
  serving_unit   TEXT,
  serving_size   TEXT,
  calories       NUMERIC,
  carbs_g        NUMERIC,
  protein_g      NUMERIC,
  fat_g          NUMERIC,
  sodium_mg      NUMERIC,
  caffeine_mg    NUMERIC,
  fluid_ml       NUMERIC,
  allergens       TEXT[] NOT NULL DEFAULT '{}',
  excluded_diets  TEXT[] NOT NULL DEFAULT '{}',
  digestion_speed TEXT
    CONSTRAINT custom_foods_digestion_speed_check
      CHECK (digestion_speed IS NULL OR digestion_speed IN ('fast', 'medium', 'slow')),
  notes        TEXT,
  is_deleted   BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_custom_foods_user
  ON custom_foods (user_id) WHERE NOT is_deleted;

ALTER TABLE custom_foods ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own custom foods" ON custom_foods;
CREATE POLICY "Users manage own custom foods"
  ON custom_foods FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION custom_foods_set_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS custom_foods_updated_at_trigger ON custom_foods;
CREATE TRIGGER custom_foods_updated_at_trigger
  BEFORE UPDATE ON custom_foods
  FOR EACH ROW EXECUTE FUNCTION custom_foods_set_updated_at();


-- ============================================================================
-- 3. personal_templates — Formula Kit columns  (PR 4)
-- ============================================================================
ALTER TABLE personal_templates
  ADD COLUMN IF NOT EXISTS provenance TEXT NOT NULL DEFAULT 'legacy_plan';

ALTER TABLE personal_templates
  ADD COLUMN IF NOT EXISTS phase              TEXT,
  ADD COLUMN IF NOT EXISTS source_template_id UUID,
  ADD COLUMN IF NOT EXISTS sub_phase          TEXT,
  ADD COLUMN IF NOT EXISTS digest_speed       TEXT,
  ADD COLUMN IF NOT EXISTS activities         JSONB,
  ADD COLUMN IF NOT EXISTS durations          JSONB,
  ADD COLUMN IF NOT EXISTS gut_training       TEXT,
  ADD COLUMN IF NOT EXISTS custom_food_ids    JSONB;

ALTER TABLE personal_templates DROP CONSTRAINT IF EXISTS personal_templates_provenance_check;
ALTER TABLE personal_templates ADD CONSTRAINT personal_templates_provenance_check
  CHECK (provenance IN ('legacy_plan', 'forked_formula', 'from_scratch_formula'));

ALTER TABLE personal_templates DROP CONSTRAINT IF EXISTS personal_templates_phase_check;
ALTER TABLE personal_templates ADD CONSTRAINT personal_templates_phase_check
  CHECK (phase IS NULL OR phase IN ('before', 'during'));

ALTER TABLE personal_templates DROP CONSTRAINT IF EXISTS personal_templates_provenance_phase_check;
ALTER TABLE personal_templates ADD CONSTRAINT personal_templates_provenance_phase_check
  CHECK (
    CASE provenance
      WHEN 'forked_formula'       THEN phase IS NOT NULL AND source_template_id IS NOT NULL
      WHEN 'from_scratch_formula' THEN phase IS NOT NULL
      ELSE TRUE
    END
  );

CREATE INDEX IF NOT EXISTS idx_personal_templates_provenance_phase
  ON personal_templates (user_id, provenance, phase);

-- ============================================================================
-- END
-- ============================================================================
