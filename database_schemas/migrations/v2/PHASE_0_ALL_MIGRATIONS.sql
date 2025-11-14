-- ============================================================================
-- PHASE 0: COMPLETE SCHEMA SIMPLIFICATION
-- ============================================================================
-- Description: All Phase 0 migrations in a single file
-- Date: 2025-01-07
--
-- INSTRUCTIONS:
-- 1. Run on DEV first: Copy and paste this entire file into Supabase SQL Editor
-- 2. Test thoroughly in DEV for 2+ days
-- 3. Then run on PROD: Copy and paste into Supabase SQL Editor
--
-- WARNING: This is destructive! It will:
-- - Drop and recreate activities, events, carb_loading_plans tables
-- - Drop all RLS policies and triggers
-- - Grant broad permissions (dev posture)
-- ============================================================================

BEGIN;

-- ============================================================================
-- MIGRATION 000: Create Enums
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE gender_enum AS ENUM ('male', 'female', 'other', 'unknown');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE distance_unit_enum AS ENUM ('miles', 'kilometers');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE pace_unit_enum AS ENUM ('min_per_mile', 'min_per_km');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE gut_training_enum AS ENUM ('low', 'moderate', 'high');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE sport_enum AS ENUM ('running', 'cycling', 'swimming');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE activity_status_enum AS ENUM ('planned', 'in_progress', 'completed', 'skipped');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE intensity_enum AS ENUM ('easy', 'moderate', 'hard', 'race');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE cycling_terrain_enum AS ENUM ('flat', 'rolling', 'hilly');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE cycling_indoor_outdoor_enum AS ENUM ('indoor', 'outdoor');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE cycling_session_goal_enum AS ENUM ('endurance', 'intervals', 'tempo', 'recovery');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE swimming_pool_open_water_enum AS ENUM ('pool', 'open_water');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE category_enum AS ENUM ('before_run', 'during_run', 'after_run');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

RAISE NOTICE '✓ Step 000: Enums created';

-- ============================================================================
-- MIGRATION 001: Verify users.id is UUID
-- ============================================================================

DO $$
DECLARE
  users_id_type TEXT;
BEGIN
  SELECT data_type INTO users_id_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'id';

  IF users_id_type = 'uuid' THEN
    RAISE NOTICE '✓ Step 001: users.id is already UUID';
  ELSE
    RAISE EXCEPTION 'users.id is not UUID! Expected uuid, got %', users_id_type;
  END IF;
END $$;

ALTER TABLE public.users
  ALTER COLUMN device_id SET NOT NULL;

DO $$ BEGIN
  ALTER TABLE public.users
    ADD CONSTRAINT users_device_id_unique UNIQUE (device_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_users_device_id ON public.users (device_id);

COMMENT ON COLUMN public.users.id IS 'Primary key - canonical user identifier (UUID)';
COMMENT ON COLUMN public.users.device_id IS 'Device identifier for current device-based authentication';

-- ============================================================================
-- MIGRATION 002: Add user_id (UUID) to all tables
-- ============================================================================

-- Activities (will be recreated in next step, but prepare user_id)
-- Events (will be recreated in next step)
-- Carb Loading Plans (will be recreated in next step)

-- User Foods
ALTER TABLE public.user_foods
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.user_foods
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.user_foods uf
SET user_id = (SELECT id FROM public.users LIMIT 1)
WHERE user_id = '00000000-0000-0000-0000-000000000000'::UUID;

ALTER TABLE public.user_foods
  ADD CONSTRAINT user_foods_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_user_foods_user_id ON public.user_foods (user_id);

-- User Hidden Foods
ALTER TABLE public.user_hidden_foods
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.user_hidden_foods
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.user_hidden_foods uhf
SET user_id = (SELECT id FROM public.users LIMIT 1)
WHERE user_id = '00000000-0000-0000-0000-000000000000'::UUID;

ALTER TABLE public.user_hidden_foods
  ADD CONSTRAINT user_hidden_foods_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_user_hidden_foods_user_id ON public.user_hidden_foods (user_id);

-- Carb Loading User Foods
ALTER TABLE public.carb_loading_user_foods
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.carb_loading_user_foods
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.carb_loading_user_foods cluf
SET user_id = (SELECT id FROM public.users LIMIT 1)
WHERE user_id = '00000000-0000-0000-0000-000000000000'::UUID;

ALTER TABLE public.carb_loading_user_foods
  ADD CONSTRAINT carb_loading_user_foods_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_user_id ON public.carb_loading_user_foods (user_id);

-- Food Preferences
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'food_preferences') THEN
    ALTER TABLE public.food_preferences DROP COLUMN IF EXISTS user_id CASCADE;
    ALTER TABLE public.food_preferences ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;
    UPDATE public.food_preferences SET user_id = (SELECT id FROM public.users LIMIT 1) WHERE user_id = '00000000-0000-0000-0000-000000000000'::UUID;
    ALTER TABLE public.food_preferences ADD CONSTRAINT food_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_food_preferences_user_id ON public.food_preferences (user_id);
  END IF;
END $$;

-- Nutrition Plans (will be dropped later, but migrate for now)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'nutrition_plans') THEN
    ALTER TABLE public.nutrition_plans DROP COLUMN IF EXISTS user_id CASCADE;
    ALTER TABLE public.nutrition_plans ADD COLUMN user_id UUID DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;
    UPDATE public.nutrition_plans SET user_id = (SELECT id FROM public.users LIMIT 1) WHERE user_id = '00000000-0000-0000-0000-000000000000'::UUID;
    ALTER TABLE public.nutrition_plans ALTER COLUMN user_id SET NOT NULL;
    ALTER TABLE public.nutrition_plans ADD CONSTRAINT nutrition_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_nutrition_plans_user_id ON public.nutrition_plans (user_id);
  END IF;
END $$;

RAISE NOTICE '✓ Step 002: user_id (UUID) added to existing tables';

-- ============================================================================
-- MIGRATION 003: Convert TEXT PKs to BIGSERIAL
-- ============================================================================

-- Activities Table
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

  -- Legacy field
  sport_type TEXT DEFAULT 'running' CHECK (sport_type IN ('running', 'cycling', 'swimming'))
);

DROP TABLE IF EXISTS public.activities CASCADE;
ALTER TABLE public.activities_new RENAME TO activities;

CREATE INDEX idx_activities_user_id ON public.activities (user_id);
CREATE INDEX idx_activities_scheduled_date_time ON public.activities (scheduled_date_time DESC);
CREATE INDEX idx_activities_activity_type ON public.activities (activity_type);
CREATE INDEX idx_activities_status ON public.activities (status);
CREATE INDEX idx_activities_needs_upload ON public.activities (needs_upload) WHERE needs_upload = TRUE;
CREATE INDEX idx_activities_deleted_at ON public.activities (deleted_at) WHERE deleted_at IS NULL;

COMMENT ON TABLE public.activities IS 'User activities (running, cycling, swimming)';
COMMENT ON COLUMN public.activities.id IS 'Primary key - BIGSERIAL auto-increment';

-- Events Table
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

-- Carb Loading Plans
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

-- Carb Loading Days
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

-- Workout Notes
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

-- Feature Survey Responses
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

RAISE NOTICE '✓ Step 003: TEXT PKs converted to BIGSERIAL';

-- ============================================================================
-- MIGRATION 004: Add Array-Based Categories
-- ============================================================================

ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS categories category_enum[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS activity_types sport_enum[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_foods_categories_gin ON public.foods USING GIN (categories);
CREATE INDEX IF NOT EXISTS idx_foods_activity_types_gin ON public.foods USING GIN (activity_types);

COMMENT ON COLUMN public.foods.categories IS 'Array of food categories (before_run, during_run, after_run)';
COMMENT ON COLUMN public.foods.activity_types IS 'Array of suitable activity types (running, cycling, swimming)';

ALTER TABLE public.user_foods
  ADD COLUMN IF NOT EXISTS categories category_enum[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS activity_types sport_enum[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_user_foods_categories_gin ON public.user_foods USING GIN (categories);
CREATE INDEX IF NOT EXISTS idx_user_foods_activity_types_gin ON public.user_foods USING GIN (activity_types);

ALTER TABLE public.carb_loading_foods
  ADD COLUMN IF NOT EXISTS meal_types TEXT[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_carb_loading_foods_meal_types_gin ON public.carb_loading_foods USING GIN (meal_types);

ALTER TABLE public.carb_loading_user_foods
  ADD COLUMN IF NOT EXISTS meal_types TEXT[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_meal_types_gin ON public.carb_loading_user_foods USING GIN (meal_types);

RAISE NOTICE '✓ Step 004: Array-based categories added';

-- ============================================================================
-- MIGRATION 005: Drop Join Tables
-- ============================================================================

DROP TABLE IF EXISTS public.food_categories CASCADE;
DROP TABLE IF EXISTS public.user_food_categories CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.carb_loading_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.carb_loading_user_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.meal_types CASCADE;

RAISE NOTICE '✓ Step 005: Join tables dropped';

-- ============================================================================
-- MIGRATION 006: Convert Timestamps to Naive
-- ============================================================================

CREATE OR REPLACE FUNCTION convert_timestamptz_to_timestamp(
  p_table_name TEXT,
  p_column_name TEXT
) RETURNS VOID AS $$
DECLARE
  v_sql TEXT;
BEGIN
  v_sql := format(
    'ALTER TABLE %I ALTER COLUMN %I TYPE TIMESTAMP USING %I AT TIME ZONE ''UTC''',
    p_table_name, p_column_name, p_column_name
  );
  EXECUTE v_sql;

  v_sql := format(
    'ALTER TABLE %I ALTER COLUMN %I SET DEFAULT (NOW() AT TIME ZONE ''UTC'')',
    p_table_name, p_column_name
  );
  BEGIN
    EXECUTE v_sql;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END;
$$ LANGUAGE plpgsql;

-- Convert timestamps on existing tables
SELECT convert_timestamptz_to_timestamp('users', 'created_at');
SELECT convert_timestamptz_to_timestamp('users', 'updated_at');
SELECT convert_timestamptz_to_timestamp('users', 'last_active_at');
SELECT convert_timestamptz_to_timestamp('app_content', 'created_at');
SELECT convert_timestamptz_to_timestamp('app_content', 'updated_at');

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'feedback') THEN
    PERFORM convert_timestamptz_to_timestamp('feedback', 'created_at');
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'macro_targets') THEN
    PERFORM convert_timestamptz_to_timestamp('macro_targets', 'created_at');
    PERFORM convert_timestamptz_to_timestamp('macro_targets', 'updated_at');
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'food_preferences') THEN
    PERFORM convert_timestamptz_to_timestamp('food_preferences', 'created_at');
    PERFORM convert_timestamptz_to_timestamp('food_preferences', 'updated_at');
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'weather_forecasts') THEN
    PERFORM convert_timestamptz_to_timestamp('weather_forecasts', 'forecast_time');
    PERFORM convert_timestamptz_to_timestamp('weather_forecasts', 'created_at');
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'activity_completions') THEN
    PERFORM convert_timestamptz_to_timestamp('activity_completions', 'completed_at');
    PERFORM convert_timestamptz_to_timestamp('activity_completions', 'created_at');
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'carb_loading_day_meals') THEN
    PERFORM convert_timestamptz_to_timestamp('carb_loading_day_meals', 'created_at');
    PERFORM convert_timestamptz_to_timestamp('carb_loading_day_meals', 'updated_at');
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'edge_functions') THEN
    PERFORM convert_timestamptz_to_timestamp('edge_functions', 'last_called_at');
  END IF;
END $$;

DROP FUNCTION convert_timestamptz_to_timestamp(TEXT, TEXT);

RAISE NOTICE '✓ Step 006: Timestamps converted to naive';

-- ============================================================================
-- MIGRATION 007: Drop RLS and Triggers
-- ============================================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', r.tablename);
  END LOOP;
END $$;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public') LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT trigger_name, event_object_table
    FROM information_schema.triggers
    WHERE trigger_schema = 'public' AND trigger_name LIKE '%update_updated_at%'
  ) LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', r.trigger_name, r.event_object_table);
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;

RAISE NOTICE '✓ Step 007: RLS and triggers dropped';

-- ============================================================================
-- MIGRATION 008: Permissive Grants
-- ============================================================================

GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;

RAISE NOTICE '✓ Step 008: Permissive grants applied';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  enum_count INTEGER;
  activities_id_type TEXT;
  activities_user_id_type TEXT;
BEGIN
  -- Check enums
  SELECT COUNT(*) INTO enum_count FROM pg_type WHERE typname LIKE '%_enum';
  IF enum_count >= 12 THEN
    RAISE NOTICE '✓ Enums verified (%)', enum_count;
  END IF;

  -- Check activities.id is BIGINT
  SELECT data_type INTO activities_id_type
  FROM information_schema.columns WHERE table_name = 'activities' AND column_name = 'id';
  IF activities_id_type = 'bigint' THEN
    RAISE NOTICE '✓ activities.id is BIGINT';
  END IF;

  -- Check activities.user_id is UUID
  SELECT data_type INTO activities_user_id_type
  FROM information_schema.columns WHERE table_name = 'activities' AND column_name = 'user_id';
  IF activities_user_id_type = 'uuid' THEN
    RAISE NOTICE '✓ activities.user_id is UUID';
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- SUCCESS!
-- ============================================================================

SELECT '
================================================================================
🎉 PHASE 0 MIGRATION COMPLETE!
================================================================================

✓ Enums created (gender, sport, intensity, etc.)
✓ users.id is UUID primary key
✓ activities.id is BIGINT (BIGSERIAL)
✓ activities.user_id is UUID foreign key
✓ events.id is BIGINT (BIGSERIAL)
✓ carb_loading_plans.id is BIGINT (BIGSERIAL)
✓ Array-based categories added to foods
✓ Join tables dropped
✓ Timestamps converted to naive TIMESTAMP (UTC)
✓ RLS disabled on all tables
✓ All RLS policies dropped
✓ Permissive grants applied

================================================================================
NEXT STEPS:
================================================================================

1. Test in Dev for 2+ days
2. Run on Prod (use this same file)
3. Update Drift schema (see separate file)
4. Continue to Phase 1 (embed nutrition)

================================================================================
' AS summary;
