-- Formula Kit: user-created custom foods (PR 4).
-- A custom food is a user-owned food a person can use as a component inside a
-- personal formula (forked or from-scratch). Mirrors the per-serving nutrition
-- shape of `template_foods` but is scoped to a single user via RLS.
--
-- Sync: offline-first, identical pattern to formula_pins / user_foods.
--   * Client writes set Drift-only `needs_upload = true` (NOT a column here).
--   * Deletes are soft (is_deleted = true) so tombstones propagate via the
--     existing upsert-only sync — never a hard DELETE.
--   * Conflict policy: last-write-wins between devices, with local-dirty
--     protection during the push window.
--
-- Idempotent: safe to paste into DataGrip and re-run against dev or prod.

CREATE TABLE IF NOT EXISTS custom_foods (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,

  -- Per-serving nutrition (mirrors the commonly-used template_foods fields).
  serving_amount NUMERIC,
  serving_unit   TEXT,
  serving_size   TEXT,              -- human-readable, e.g. "1 scoop (30g)"
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

  -- Soft delete (matches user_foods / formula_pins convention).
  is_deleted   BOOLEAN NOT NULL DEFAULT false,

  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_custom_foods_user
  ON custom_foods (user_id)
  WHERE NOT is_deleted;

-- RLS: a user can read/write only their own custom foods.
ALTER TABLE custom_foods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own custom foods" ON custom_foods;
CREATE POLICY "Users manage own custom foods"
  ON custom_foods FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- updated_at trigger (matches existing convention)
CREATE OR REPLACE FUNCTION custom_foods_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS custom_foods_updated_at_trigger ON custom_foods;
CREATE TRIGGER custom_foods_updated_at_trigger
  BEFORE UPDATE ON custom_foods
  FOR EACH ROW EXECUTE FUNCTION custom_foods_set_updated_at();
