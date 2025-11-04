-- Migration: Add macro_targets and workout_notes to complete v1 schema
-- Description: Adds the final 2 tables for 100% schema parity (26 tables total)
-- Date: 2025-10-08
-- Schema Version: v1
-- Tables: macro_targets_table, workout_notes

-- ============================================================================
-- Table 1: macro_targets_table
-- Purpose: Stores calculated nutrition targets for running sessions
-- ============================================================================

CREATE TABLE IF NOT EXISTS macro_targets_table (
  id TEXT PRIMARY KEY CHECK (length(id) >= 1 AND length(id) <= 50),

  -- Pre-run macros
  pre_run_carbs_g NUMERIC NOT NULL,
  pre_run_protein_g NUMERIC NOT NULL,
  pre_run_fat_cap_g NUMERIC NOT NULL,
  pre_run_fluids_ml NUMERIC NOT NULL,
  pre_run_sodium_mg NUMERIC NOT NULL,

  -- During-run macros
  during_carb_rate_g_per_h NUMERIC NOT NULL,
  during_carb_total_g NUMERIC NOT NULL,
  during_fluid_rate_ml_per_h NUMERIC NOT NULL,
  during_fluid_total_ml NUMERIC NOT NULL,
  during_sodium_rate_mg_per_h NUMERIC NOT NULL,
  during_sodium_total_mg NUMERIC NOT NULL,
  during_mass_norm_rate_g_per_h NUMERIC,

  -- Post-run macros
  post_run_carbs_g NUMERIC NOT NULL,
  post_run_protein_g NUMERIC NOT NULL,
  post_run_fluids_ml NUMERIC NOT NULL,
  post_run_sodium_mg NUMERIC NOT NULL,

  -- Run metrics
  distance_mi NUMERIC NOT NULL,
  duration_h NUMERIC NOT NULL,
  pace_min_per_mile NUMERIC NOT NULL,
  calories_gross_kcal NUMERIC NOT NULL,
  met NUMERIC NOT NULL,

  -- Metadata
  calculation_rule TEXT NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  is_user_modified BOOLEAN NOT NULL DEFAULT false,
  modified_fields TEXT NOT NULL DEFAULT '',

  -- Check constraints for positive values
  CONSTRAINT check_pre_run_carbs_positive CHECK (pre_run_carbs_g >= 0),
  CONSTRAINT check_pre_run_protein_positive CHECK (pre_run_protein_g >= 0),
  CONSTRAINT check_pre_run_fat_positive CHECK (pre_run_fat_cap_g >= 0),
  CONSTRAINT check_pre_run_fluids_positive CHECK (pre_run_fluids_ml >= 0),
  CONSTRAINT check_pre_run_sodium_positive CHECK (pre_run_sodium_mg >= 0),
  CONSTRAINT check_during_carb_rate_positive CHECK (during_carb_rate_g_per_h >= 0),
  CONSTRAINT check_during_carb_total_positive CHECK (during_carb_total_g >= 0),
  CONSTRAINT check_during_fluid_rate_positive CHECK (during_fluid_rate_ml_per_h >= 0),
  CONSTRAINT check_during_fluid_total_positive CHECK (during_fluid_total_ml >= 0),
  CONSTRAINT check_during_sodium_rate_positive CHECK (during_sodium_rate_mg_per_h >= 0),
  CONSTRAINT check_during_sodium_total_positive CHECK (during_sodium_total_mg >= 0),
  CONSTRAINT check_post_run_carbs_positive CHECK (post_run_carbs_g >= 0),
  CONSTRAINT check_post_run_protein_positive CHECK (post_run_protein_g >= 0),
  CONSTRAINT check_post_run_fluids_positive CHECK (post_run_fluids_ml >= 0),
  CONSTRAINT check_post_run_sodium_positive CHECK (post_run_sodium_mg >= 0),
  CONSTRAINT check_distance_positive CHECK (distance_mi > 0),
  CONSTRAINT check_duration_positive CHECK (duration_h > 0),
  CONSTRAINT check_pace_positive CHECK (pace_min_per_mile > 0),
  CONSTRAINT check_calories_positive CHECK (calories_gross_kcal >= 0),
  CONSTRAINT check_met_positive CHECK (met > 0)
);

COMMENT ON TABLE macro_targets_table IS 'Calculated nutrition targets for running sessions (26 columns)';
COMMENT ON COLUMN macro_targets_table.id IS 'Unique identifier for this macro target set';
COMMENT ON COLUMN macro_targets_table.calculation_rule IS 'Algorithm version/rule used for calculations';
COMMENT ON COLUMN macro_targets_table.is_user_modified IS 'Whether user has manually adjusted these targets';
COMMENT ON COLUMN macro_targets_table.modified_fields IS 'Comma-separated list of user-modified field names';

CREATE INDEX IF NOT EXISTS idx_macro_targets_timestamp ON macro_targets_table(timestamp);
CREATE INDEX IF NOT EXISTS idx_macro_targets_distance ON macro_targets_table(distance_mi);

-- ============================================================================
-- Table 2: workout_notes
-- Purpose: User workout journal entries
-- ============================================================================

CREATE TABLE IF NOT EXISTS workout_notes (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL,
  plan_id TEXT,
  note_text TEXT NOT NULL,
  rating INTEGER CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5)),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  CONSTRAINT fk_workout_notes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

COMMENT ON TABLE workout_notes IS 'User workout journal entries with optional ratings';
COMMENT ON COLUMN workout_notes.user_id IS 'References users.id (not device_id)';
COMMENT ON COLUMN workout_notes.plan_id IS 'Optional reference to nutrition_plans.id';
COMMENT ON COLUMN workout_notes.rating IS 'Optional 1-5 scale rating';

CREATE INDEX IF NOT EXISTS idx_workout_notes_user ON workout_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_workout_notes_plan ON workout_notes(plan_id) WHERE plan_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_workout_notes_created ON workout_notes(created_at);

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on both tables
ALTER TABLE macro_targets_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_notes ENABLE ROW LEVEL SECURITY;

-- macro_targets_table: Public read (calculated data, no sensitive info)
-- Note: In production, you may want to restrict this to authenticated users
CREATE POLICY "macro_targets_public_read" ON macro_targets_table
  FOR SELECT USING (true);

CREATE POLICY "macro_targets_authenticated_insert" ON macro_targets_table
  FOR INSERT WITH CHECK (true);

CREATE POLICY "macro_targets_authenticated_update" ON macro_targets_table
  FOR UPDATE USING (true);

-- workout_notes: User-based access (user_id references users.id)
CREATE POLICY "workout_notes_user_read" ON workout_notes
  FOR SELECT USING (user_id = current_setting('app.user_id', true)::uuid);

CREATE POLICY "workout_notes_user_insert" ON workout_notes
  FOR INSERT WITH CHECK (user_id = current_setting('app.user_id', true)::uuid);

CREATE POLICY "workout_notes_user_update" ON workout_notes
  FOR UPDATE USING (user_id = current_setting('app.user_id', true)::uuid);

CREATE POLICY "workout_notes_user_delete" ON workout_notes
  FOR DELETE USING (user_id = current_setting('app.user_id', true)::uuid);

-- ============================================================================
-- Migration Complete
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'V1 schema completion migration successful';
  RAISE NOTICE 'Tables added: macro_targets_table, workout_notes';
  RAISE NOTICE 'Total v1 tables: 26 (100%% parity with Drift)';
END $$;
