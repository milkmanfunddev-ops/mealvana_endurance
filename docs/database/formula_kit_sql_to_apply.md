# Formula Kit — SQL to apply (DataGrip)

These are the schema changes the Formula Kit feature needs. We apply schema by
**pasting SQL into DataGrip manually** (not `supabase db push`). All blocks are
**idempotent** — safe to re-run. Apply each to **dev AND prod**.

✅ **Applied to dev + prod on 2026-05-22** (migration files now in `_archived/`).

Source migration files (same content, kept for the repo record):
- `supabase/migrations/_archived/20260520120000_formula_pins.sql`
- `supabase/migrations/_archived/20260522120000_custom_foods.sql`
- `supabase/migrations/_archived/20260522120100_personal_templates_formula_kit_columns.sql`

| # | Block | dev | prod | Notes |
|---|-------|-----|------|-------|
| 1 | `formula_pins` | ✅ | ✅ | Needed for pins to sync (PR 2). |
| 2 | `custom_foods` | ✅ | ✅ | PR 4 prep. No Dart consumes it yet. |
| 3 | `personal_templates` columns | ✅ | ✅ | PR 4 prep. Additive; existing rows backfill to `legacy_plan`. |

> ⚠️ **These are schema prep.** Blocks 2 and 3 won't change app behavior until
> the PR 4 Dart + edge-function wiring is built. Block 1 is needed for pins.
> All three are additive and safe for old app versions (they `SELECT *` and
> ignore unknown columns; they never reference `custom_foods`).

---

## 1. formula_pins (PR 2)

```sql
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
```

## 2. custom_foods (PR 4)

```sql
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
```

## 3. personal_templates Formula-Kit columns (PR 4)

```sql
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
```
