-- Formula Kit: evolve personal_templates to serve both legacy "saved plan"
-- rows AND new Formula Kit personal-formula rows (PR 4).
--
-- This is an ADDITIVE evolution — not a parallel table. Existing rows are
-- backfilled to provenance='legacy_plan' (handled automatically by the NOT
-- NULL DEFAULT on the new column), so the legacy "My Templates" surface keeps
-- working unchanged. Old app binaries that SELECT * simply receive extra
-- columns they ignore; old binaries never reference the new names.
--
-- Idempotent: ADD COLUMN IF NOT EXISTS + DROP/ADD CONSTRAINT guards make this
-- safe to paste into DataGrip and re-run against dev or prod.

-- 1. Provenance discriminator. NOT NULL DEFAULT backfills every existing row
--    to 'legacy_plan' automatically.
ALTER TABLE personal_templates
  ADD COLUMN IF NOT EXISTS provenance TEXT NOT NULL DEFAULT 'legacy_plan';

-- 2. Formula-row metadata (NULL for legacy plans).
ALTER TABLE personal_templates
  ADD COLUMN IF NOT EXISTS phase              TEXT,    -- 'before' | 'during' (NULL for legacy)
  ADD COLUMN IF NOT EXISTS source_template_id UUID,    -- pre_/during_workout_templates.id (forked only); polymorphic, no FK
  ADD COLUMN IF NOT EXISTS sub_phase          TEXT,    -- Before: 'full_meal' | 'snack' | 'top_up'
  ADD COLUMN IF NOT EXISTS digest_speed       TEXT,    -- 'fast' | 'medium' (Before)
  ADD COLUMN IF NOT EXISTS activities         JSONB,   -- During only: array of activity types
  ADD COLUMN IF NOT EXISTS durations          JSONB,   -- During only: array of duration brackets
  ADD COLUMN IF NOT EXISTS gut_training       TEXT,    -- During only: gut-training level
  ADD COLUMN IF NOT EXISTS custom_food_ids    JSONB;   -- array of custom_foods.id used as components

-- 3. Value-domain checks (idempotent via DROP/ADD).
ALTER TABLE personal_templates
  DROP CONSTRAINT IF EXISTS personal_templates_provenance_check;
ALTER TABLE personal_templates
  ADD CONSTRAINT personal_templates_provenance_check
    CHECK (provenance IN ('legacy_plan', 'forked_formula', 'from_scratch_formula'));

ALTER TABLE personal_templates
  DROP CONSTRAINT IF EXISTS personal_templates_phase_check;
ALTER TABLE personal_templates
  ADD CONSTRAINT personal_templates_phase_check
    CHECK (phase IS NULL OR phase IN ('before', 'during'));

-- 4. Provenance + phase integrity:
--    * forked_formula     → must have phase AND source_template_id
--    * from_scratch_formula → must have phase (no source template)
--    * legacy_plan        → no requirement (phase/source stay NULL)
ALTER TABLE personal_templates
  DROP CONSTRAINT IF EXISTS personal_templates_provenance_phase_check;
ALTER TABLE personal_templates
  ADD CONSTRAINT personal_templates_provenance_phase_check
    CHECK (
      CASE provenance
        WHEN 'forked_formula'       THEN phase IS NOT NULL AND source_template_id IS NOT NULL
        WHEN 'from_scratch_formula' THEN phase IS NOT NULL
        ELSE TRUE
      END
    );

-- 5. Index for the Formula Kit "Your formulas" listing (formula rows by user+phase).
CREATE INDEX IF NOT EXISTS idx_personal_templates_provenance_phase
  ON personal_templates (user_id, provenance, phase);

-- RLS policy is intentionally left unchanged — already user-owned via user_id.

COMMENT ON COLUMN personal_templates.provenance IS
  'legacy_plan (pre-Formula-Kit saved plans) | forked_formula | from_scratch_formula';
COMMENT ON COLUMN personal_templates.source_template_id IS
  'When provenance=forked_formula: id of the pre_workout_templates or during_workout_templates row this was forked from. Polymorphic — no FK.';
COMMENT ON COLUMN personal_templates.custom_food_ids IS
  'JSON array of custom_foods.id values used as components in this formula.';
