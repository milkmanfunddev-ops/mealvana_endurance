-- Formula Kit pins: user-declared preference signals for plan generation.
-- When pins exist matching a workout's scope, the algorithm tries pinned
-- templates first; falls through to existing scoring if none fit.
-- See docs/features/formula-kit/PLAN.md (PR 2).

CREATE TABLE formula_pins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  template_id UUID NOT NULL,
  -- Polymorphic ref into pre_workout_templates or during_workout_templates.
  -- Intentionally text, not FK — widened to 'personal_template' in PR 4.
  template_kind TEXT NOT NULL CHECK (template_kind IN ('pre_system', 'during_system')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Soft delete (matches user_foods convention). Unpinning sets is_deleted=true
  -- so the change propagates correctly across devices via the existing
  -- upsert-only sync handler. See user_food_crud_service.dart for precedent.
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- One active pin per (user, template, kind). Re-pinning a soft-deleted row
-- inserts a new active row (with new id); the old tombstone stays for sync.
CREATE UNIQUE INDEX formula_pins_active_unique
  ON formula_pins (user_id, template_id, template_kind)
  WHERE NOT is_deleted;

-- Algorithm reads pins by (user, kind); indexed for hot path.
CREATE INDEX formula_pins_user_kind
  ON formula_pins (user_id, template_kind)
  WHERE NOT is_deleted;

ALTER TABLE formula_pins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own pins"
  ON formula_pins FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- updated_at trigger (matches existing convention)
CREATE OR REPLACE FUNCTION formula_pins_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER formula_pins_updated_at_trigger
  BEFORE UPDATE ON formula_pins
  FOR EACH ROW EXECUTE FUNCTION formula_pins_set_updated_at();
