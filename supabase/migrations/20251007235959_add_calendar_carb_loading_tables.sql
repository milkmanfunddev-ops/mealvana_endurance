-- Migration: Add Calendar and Carb Loading Tables to v1 Schema
-- Description: Adds calendar/activities tables and carb loading plan/day tables
-- Tables: activities, events, carb_loading_plans, carb_loading_days, activity_completions
-- Date: 2025-10-07 (before food tables migration)
-- Schema Version: v1 (matching Drift schema)

-- ============================================================================
-- Table 1: activities
-- Purpose: All calendar entries including workouts and events
-- ============================================================================

CREATE TABLE IF NOT EXISTS activities (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  activity_type TEXT NOT NULL,
  title TEXT NOT NULL,
  scheduled_date_time TIMESTAMP NOT NULL,
  status TEXT DEFAULT 'planned',
  distance_miles REAL,
  duration_minutes INTEGER,
  pace_target_minutes_per_mile REAL,
  intensity_level TEXT,
  completed_at TIMESTAMP,
  completion_rating INTEGER,
  completion_notes TEXT,
  actual_distance_miles REAL,
  actual_duration_minutes INTEGER,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP,
  CONSTRAINT activity_type_check CHECK (activity_type IN ('running', 'event')),
  CONSTRAINT status_check CHECK (status IN ('planned', 'in_progress', 'completed', 'skipped')),
  CONSTRAINT intensity_check CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race')),
  CONSTRAINT rating_check CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5))
);

COMMENT ON TABLE activities IS 'All calendar entries including workouts and events';
COMMENT ON COLUMN activities.activity_type IS 'Type: running (workout) or event (race)';
COMMENT ON COLUMN activities.status IS 'Current status: planned, in_progress, completed, skipped';

CREATE INDEX IF NOT EXISTS idx_activities_user ON activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_scheduled ON activities(scheduled_date_time);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_status ON activities(status);

-- ============================================================================
-- Table 2: events
-- Purpose: Specialized event data linked to activities (races, competitions)
-- ============================================================================

CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  activity_id TEXT UNIQUE NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_subtype TEXT,
  event_name TEXT,
  location TEXT,
  registration_url TEXT,
  start_time TEXT,
  goal_time_minutes INTEGER,
  goal_pace_minutes_per_mile REAL,
  predicted_finish_time_minutes INTEGER,
  has_carb_loading BOOLEAN DEFAULT false,
  carb_loading_days INTEGER,
  carb_loading_start_date TIMESTAMP,
  bib_number TEXT,
  wave_start_time TEXT,
  packet_pickup_info TEXT,
  actual_finish_time_minutes INTEGER,
  final_placement INTEGER,
  age_group_placement INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT event_type_check CHECK (event_type IN ('marathon', 'half_marathon', '10k', '5k', 'ultra_50k', 'ultra_50m', 'ultra_100k', 'ultra_100m', 'custom')),
  CONSTRAINT carb_days_check CHECK (carb_loading_days IS NULL OR carb_loading_days IN (1, 2, 3, 7))
);

COMMENT ON TABLE events IS 'Specialized event data for races and competitions';
COMMENT ON COLUMN events.activity_id IS 'One-to-one link to activities table';
COMMENT ON COLUMN events.has_carb_loading IS 'Whether this event has an associated carb loading plan';

CREATE INDEX IF NOT EXISTS idx_events_activity ON events(activity_id);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_carb_loading ON events(has_carb_loading) WHERE has_carb_loading = true;

-- ============================================================================
-- Table 3: carb_loading_plans
-- Purpose: Enhanced carb loading plans for events
-- ============================================================================

CREATE TABLE IF NOT EXISTS carb_loading_plans (
  id TEXT PRIMARY KEY,
  event_id TEXT UNIQUE NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  total_days INTEGER NOT NULL,
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP NOT NULL,
  daily_carb_target_grams INTEGER NOT NULL,
  daily_calorie_target INTEGER,
  generated_at TIMESTAMP NOT NULL,
  algorithm_version TEXT DEFAULT 'v1.0',
  adherence_score REAL,
  completed_at TIMESTAMP,
  CONSTRAINT total_days_check CHECK (total_days IN (1, 2, 3, 7)),
  CONSTRAINT adherence_check CHECK (adherence_score IS NULL OR (adherence_score >= 0.0 AND adherence_score <= 1.0))
);

COMMENT ON TABLE carb_loading_plans IS 'Carb loading plans linked to specific events';
COMMENT ON COLUMN carb_loading_plans.event_id IS 'One-to-one link to events table';
COMMENT ON COLUMN carb_loading_plans.adherence_score IS '0.0 to 1.0 based on logged meals';

CREATE INDEX IF NOT EXISTS idx_carb_plans_event ON carb_loading_plans(event_id);
CREATE INDEX IF NOT EXISTS idx_carb_plans_user ON carb_loading_plans(user_id);
CREATE INDEX IF NOT EXISTS idx_carb_plans_dates ON carb_loading_plans(start_date, end_date);

-- ============================================================================
-- Table 4: carb_loading_days
-- Purpose: Individual day entries within a carb loading plan
-- ============================================================================

CREATE TABLE IF NOT EXISTS carb_loading_days (
  id TEXT PRIMARY KEY,
  carb_loading_plan_id TEXT NOT NULL REFERENCES carb_loading_plans(id) ON DELETE CASCADE,
  plan_date TIMESTAMP NOT NULL,
  day_number INTEGER NOT NULL,
  carb_target_grams INTEGER NOT NULL,
  calorie_target INTEGER,
  meal_count INTEGER DEFAULT 6,
  breakfast_percent REAL DEFAULT 0.25,
  morning_snack_percent REAL DEFAULT 0.10,
  lunch_percent REAL DEFAULT 0.25,
  afternoon_snack_percent REAL DEFAULT 0.15,
  dinner_percent REAL DEFAULT 0.20,
  evening_snack_percent REAL DEFAULT 0.05,
  logged_carbs_grams INTEGER DEFAULT 0,
  logged_calories INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT false,
  CONSTRAINT day_number_check CHECK (day_number > 0),
  CONSTRAINT carb_target_check CHECK (carb_target_grams > 0),
  CONSTRAINT meal_count_check CHECK (meal_count > 0),
  CONSTRAINT breakfast_percent_check CHECK (breakfast_percent >= 0.0 AND breakfast_percent <= 1.0),
  CONSTRAINT morning_snack_percent_check CHECK (morning_snack_percent >= 0.0 AND morning_snack_percent <= 1.0),
  CONSTRAINT lunch_percent_check CHECK (lunch_percent >= 0.0 AND lunch_percent <= 1.0),
  CONSTRAINT afternoon_snack_percent_check CHECK (afternoon_snack_percent >= 0.0 AND afternoon_snack_percent <= 1.0),
  CONSTRAINT dinner_percent_check CHECK (dinner_percent >= 0.0 AND dinner_percent <= 1.0),
  CONSTRAINT evening_snack_percent_check CHECK (evening_snack_percent >= 0.0 AND evening_snack_percent <= 1.0),
  CONSTRAINT logged_carbs_check CHECK (logged_carbs_grams >= 0),
  CONSTRAINT logged_calories_check CHECK (logged_calories >= 0),
  UNIQUE (carb_loading_plan_id, plan_date)
);

COMMENT ON TABLE carb_loading_days IS 'Individual day entries within carb loading plans';
COMMENT ON COLUMN carb_loading_days.day_number IS '1, 2, 3, etc. (last number = race day - 1)';
COMMENT ON COLUMN carb_loading_days.meal_count IS 'Default 6: breakfast, snack, lunch, snack, dinner, evening';

CREATE INDEX IF NOT EXISTS idx_carb_days_plan ON carb_loading_days(carb_loading_plan_id);
CREATE INDEX IF NOT EXISTS idx_carb_days_date ON carb_loading_days(plan_date);
CREATE INDEX IF NOT EXISTS idx_carb_days_completed ON carb_loading_days(completed);

-- ============================================================================
-- Table 5: activity_completions
-- Purpose: Completion records for activities
-- ============================================================================

CREATE TABLE IF NOT EXISTS activity_completions (
  id TEXT PRIMARY KEY,
  activity_id TEXT UNIQUE NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  completed_at TIMESTAMP NOT NULL,
  actual_distance_miles REAL,
  actual_duration_minutes INTEGER,
  average_pace_minutes_per_mile REAL,
  completion_rating INTEGER,
  completion_notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT rating_check CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5))
);

COMMENT ON TABLE activity_completions IS 'Completion records for activities';
COMMENT ON COLUMN activity_completions.activity_id IS 'One-to-one link to activities table';

CREATE INDEX IF NOT EXISTS idx_activity_completions_activity ON activity_completions(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_completions_date ON activity_completions(completed_at);

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE carb_loading_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE carb_loading_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_completions ENABLE ROW LEVEL SECURITY;

-- Activities policies (user_id based)
CREATE POLICY activities_select_policy ON activities
  FOR SELECT USING (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_insert_policy ON activities
  FOR INSERT WITH CHECK (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_update_policy ON activities
  FOR UPDATE USING (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_delete_policy ON activities
  FOR DELETE USING (user_id = current_setting('app.user_id', true));

-- Events policies (via activities.user_id)
CREATE POLICY events_select_policy ON events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = events.activity_id
      AND activities.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY events_insert_policy ON events
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = events.activity_id
      AND activities.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY events_update_policy ON events
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = events.activity_id
      AND activities.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY events_delete_policy ON events
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = events.activity_id
      AND activities.user_id = current_setting('app.user_id', true)
    )
  );

-- Carb loading plans policies (user_id based)
CREATE POLICY carb_plans_select_policy ON carb_loading_plans
  FOR SELECT USING (user_id = current_setting('app.user_id', true));

CREATE POLICY carb_plans_insert_policy ON carb_loading_plans
  FOR INSERT WITH CHECK (user_id = current_setting('app.user_id', true));

CREATE POLICY carb_plans_update_policy ON carb_loading_plans
  FOR UPDATE USING (user_id = current_setting('app.user_id', true));

CREATE POLICY carb_plans_delete_policy ON carb_loading_plans
  FOR DELETE USING (user_id = current_setting('app.user_id', true));

-- Carb loading days policies (via plans.user_id)
CREATE POLICY carb_days_select_policy ON carb_loading_days
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM carb_loading_plans
      WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND carb_loading_plans.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY carb_days_insert_policy ON carb_loading_days
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM carb_loading_plans
      WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND carb_loading_plans.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY carb_days_update_policy ON carb_loading_days
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM carb_loading_plans
      WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND carb_loading_plans.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY carb_days_delete_policy ON carb_loading_days
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM carb_loading_plans
      WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND carb_loading_plans.user_id = current_setting('app.user_id', true)
    )
  );

-- Activity completions policies (via activities.user_id)
CREATE POLICY activity_completions_select_policy ON activity_completions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = activity_completions.activity_id
      AND activities.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY activity_completions_insert_policy ON activity_completions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = activity_completions.activity_id
      AND activities.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY activity_completions_update_policy ON activity_completions
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = activity_completions.activity_id
      AND activities.user_id = current_setting('app.user_id', true)
    )
  );

CREATE POLICY activity_completions_delete_policy ON activity_completions
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = activity_completions.activity_id
      AND activities.user_id = current_setting('app.user_id', true)
    )
  );
