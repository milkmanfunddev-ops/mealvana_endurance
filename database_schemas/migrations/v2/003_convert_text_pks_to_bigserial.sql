-- ============================================================================
-- Migration 003: Convert TEXT Primary Keys to BIGSERIAL
-- ============================================================================
-- Description: Convert TEXT PKs to BIGINT auto-increment for better performance
-- Date: 2025-01-07
-- WARNING: This is destructive! Only run on fresh database or with data migration
-- ============================================================================

BEGIN;

-- ============================================================================
-- Activities Table: TEXT → BIGSERIAL
-- ============================================================================

-- Step 1: Create new activities table with BIGSERIAL PK
CREATE TABLE public.activities_new (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL CHECK (activity_type IN ('running', 'cycling', 'swimming')),
  title TEXT NOT NULL,
  scheduled_date_time TIMESTAMP NOT NULL,
  status TEXT DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'skipped')),

  -- Running/general fields
  distance_miles REAL,
  duration_minutes INTEGER,
  pace_target_minutes_per_mile REAL,
  intensity_level TEXT CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race')),

  -- Cycling fields
  cycling_speed_mph REAL,
  cycling_terrain TEXT CHECK (cycling_terrain IS NULL OR cycling_terrain IN ('flat', 'rolling', 'hilly')),
  cycling_indoor_outdoor TEXT CHECK (cycling_indoor_outdoor IS NULL OR cycling_indoor_outdoor IN ('indoor', 'outdoor')),
  cycling_elevation_gain_ft INTEGER,
  cycling_session_goal TEXT CHECK (cycling_session_goal IS NULL OR cycling_session_goal IN ('endurance', 'intervals', 'tempo', 'recovery')),
  cycling_power_watts INTEGER,
  cycling_ftp_watts INTEGER,

  -- Swimming fields
  swimming_pace_per_100m_seconds INTEGER,
  swimming_pool_or_open_water TEXT CHECK (swimming_pool_or_open_water IS NULL OR swimming_pool_or_open_water IN ('pool', 'open_water')),
  swimming_water_temp_c REAL,
  swimming_speed_per_100m INTEGER,
  swimming_css_seconds_per_100m INTEGER,

  -- Completion fields
  completed_at TIMESTAMP,
  completion_rating INTEGER CHECK (completion_rating IS NULL OR (completion_rating BETWEEN 1 AND 5)),
  completion_notes TEXT,
  actual_distance_miles REAL,
  actual_duration_minutes INTEGER,

  -- Metadata
  notes TEXT,
  created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  deleted_at TIMESTAMP,

  -- Sync tracking
  needs_upload BOOLEAN DEFAULT TRUE,
  local_updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),

  -- Legacy field (will be removed)
  sport_type TEXT DEFAULT 'running' CHECK (sport_type IN ('running', 'cycling', 'swimming'))
);

-- Step 2: Migrate existing data (if any)
-- Since we're doing a fresh migration, we can skip this
-- INSERT INTO activities_new (user_id, activity_type, title, ...)
-- SELECT user_id, activity_type, title, ... FROM activities;

-- Step 3: Drop old table and rename
DROP TABLE IF EXISTS public.activities CASCADE;
ALTER TABLE public.activities_new RENAME TO activities;

-- Step 4: Create indexes
CREATE INDEX idx_activities_user_id ON public.activities (user_id);
CREATE INDEX idx_activities_scheduled_date_time ON public.activities (scheduled_date_time DESC);
CREATE INDEX idx_activities_activity_type ON public.activities (activity_type);
CREATE INDEX idx_activities_status ON public.activities (status);
CREATE INDEX idx_activities_needs_upload ON public.activities (needs_upload) WHERE needs_upload = TRUE;
CREATE INDEX idx_activities_deleted_at ON public.activities (deleted_at) WHERE deleted_at IS NULL;

-- Step 5: Add comments
COMMENT ON TABLE public.activities IS 'User activities (running, cycling, swimming)';
COMMENT ON COLUMN public.activities.id IS 'Primary key - BIGSERIAL auto-increment';
COMMENT ON COLUMN public.activities.user_id IS 'Foreign key to users.id (UUID)';
COMMENT ON COLUMN public.activities.needs_upload IS 'Flag for offline-first sync';

-- ============================================================================
-- Events Table: TEXT → BIGSERIAL
-- ============================================================================

CREATE TABLE public.events_new (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  start_time TIMESTAMP NOT NULL,
  activity_id BIGINT REFERENCES public.activities(id) ON DELETE SET NULL,
  carb_loading_start_date DATE,
  notes TEXT,
  created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  needs_upload BOOLEAN DEFAULT TRUE,
  local_updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC')
);

DROP TABLE IF EXISTS public.events CASCADE;
ALTER TABLE public.events_new RENAME TO events;

CREATE INDEX idx_events_user_id ON public.events (user_id);
CREATE INDEX idx_events_start_time ON public.events (start_time DESC);
CREATE INDEX idx_events_activity_id ON public.events (activity_id);

COMMENT ON TABLE public.events IS 'User calendar events (races, competitions)';
COMMENT ON COLUMN public.events.id IS 'Primary key - BIGSERIAL auto-increment';

-- ============================================================================
-- Carb Loading Plans Table: TEXT → BIGSERIAL
-- ============================================================================

CREATE TABLE public.carb_loading_plans_new (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  race_date DATE NOT NULL,
  race_name TEXT,
  race_distance_miles REAL,
  days_before_race INTEGER NOT NULL,
  daily_carb_target_grams INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  needs_upload BOOLEAN DEFAULT TRUE,
  local_updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC')
);

DROP TABLE IF EXISTS public.carb_loading_plans CASCADE;
ALTER TABLE public.carb_loading_plans_new RENAME TO carb_loading_plans;

CREATE INDEX idx_carb_loading_plans_user_id ON public.carb_loading_plans (user_id);
CREATE INDEX idx_carb_loading_plans_race_date ON public.carb_loading_plans (race_date DESC);

COMMENT ON TABLE public.carb_loading_plans IS 'Carb loading plans for race preparation';
COMMENT ON COLUMN public.carb_loading_plans.id IS 'Primary key - BIGSERIAL auto-increment';

-- ============================================================================
-- Carb Loading Days Table: TEXT → BIGSERIAL
-- ============================================================================

CREATE TABLE public.carb_loading_days_new (
  id BIGSERIAL PRIMARY KEY,
  carb_loading_plan_id BIGINT NOT NULL REFERENCES public.carb_loading_plans(id) ON DELETE CASCADE,
  day_date DATE NOT NULL,
  day_number INTEGER NOT NULL,
  carb_target_grams INTEGER NOT NULL,
  carb_actual_grams INTEGER,
  notes TEXT,
  created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC')
);

DROP TABLE IF EXISTS public.carb_loading_days CASCADE;
ALTER TABLE public.carb_loading_days_new RENAME TO carb_loading_days;

CREATE INDEX idx_carb_loading_days_plan_id ON public.carb_loading_days (carb_loading_plan_id);
CREATE INDEX idx_carb_loading_days_day_date ON public.carb_loading_days (day_date);

COMMENT ON TABLE public.carb_loading_days IS 'Individual days in carb loading plan';
COMMENT ON COLUMN public.carb_loading_days.id IS 'Primary key - BIGSERIAL auto-increment';

-- ============================================================================
-- Workout Notes Table: TEXT → BIGSERIAL
-- ============================================================================

CREATE TABLE public.workout_notes_new (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  device_id TEXT,
  activity_id BIGINT REFERENCES public.activities(id) ON DELETE CASCADE,
  notes TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC')
);

DROP TABLE IF EXISTS public.workout_notes CASCADE;
ALTER TABLE public.workout_notes_new RENAME TO workout_notes;

CREATE INDEX idx_workout_notes_activity_id ON public.workout_notes (activity_id);

COMMENT ON TABLE public.workout_notes IS 'User notes for workout activities';
COMMENT ON COLUMN public.workout_notes.id IS 'Primary key - BIGSERIAL auto-increment';

-- ============================================================================
-- Feature Survey Responses Table: TEXT → BIGSERIAL
-- ============================================================================

CREATE TABLE public.feature_survey_responses_new (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  device_id TEXT,
  feature_name TEXT NOT NULL,
  response_data JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC')
);

DROP TABLE IF EXISTS public.feature_survey_responses CASCADE;
ALTER TABLE public.feature_survey_responses_new RENAME TO feature_survey_responses;

CREATE INDEX idx_feature_survey_responses_user_id ON public.feature_survey_responses (user_id);
CREATE INDEX idx_feature_survey_responses_feature_name ON public.feature_survey_responses (feature_name);

COMMENT ON TABLE public.feature_survey_responses IS 'User responses to feature surveys';
COMMENT ON COLUMN public.feature_survey_responses.id IS 'Primary key - BIGSERIAL auto-increment';

COMMIT;

SELECT 'TEXT PKs converted to BIGSERIAL successfully' AS status;
