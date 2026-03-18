-- Personal Templates: Save and reuse nutrition plans
CREATE TABLE personal_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  activity_type TEXT NOT NULL,  -- 'running'/'cycling'/'swimming'/'brick'

  -- Original activity context
  original_duration_minutes INTEGER,
  original_distance NUMERIC(8,2),  -- miles for run/cycle, meters for swim
  original_activity_title TEXT,

  -- Full plan data (same JSON format as activities.nutrition_plan_data)
  plan_data JSONB NOT NULL,

  -- Denormalized macro totals (for quick display in picker)
  total_carbs_g INTEGER,
  total_protein_g INTEGER,
  total_fat_g INTEGER,
  total_sodium_mg INTEGER,
  total_fluids_ml INTEGER,
  total_calories INTEGER,

  -- Brick metadata (null for single-sport)
  brick_segment_order TEXT[],  -- e.g., ['swimming','cycling','running']

  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE personal_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own templates"
  ON personal_templates FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX idx_personal_templates_user ON personal_templates(user_id);
CREATE INDEX idx_personal_templates_sport ON personal_templates(user_id, activity_type);
