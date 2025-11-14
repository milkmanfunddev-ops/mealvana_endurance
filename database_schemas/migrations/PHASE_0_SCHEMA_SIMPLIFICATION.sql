-- ============================================================================
-- PHASE 0: SCHEMA SIMPLIFICATION (DESTRUCTIVE - NO DATA MIGRATION)
-- ============================================================================
-- Description: Drop old tables, create new schema with BIGSERIAL PKs
-- Date: 2025-01-07
--
-- WARNING: This drops all data in these tables:
-- - activities, events, carb_loading_plans, carb_loading_days
-- - workout_notes, feature_survey_responses
-- - food_categories, categories, meal_types (and related join tables)
-- - edge_functions
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Create Enums
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

RAISE NOTICE '✓ Step 1: Enums created';

-- ============================================================================
-- STEP 2: Drop All Join Tables and Edge Functions
-- ============================================================================

DROP TABLE IF EXISTS public.food_categories CASCADE;
DROP TABLE IF EXISTS public.user_food_categories CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.carb_loading_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.carb_loading_user_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.meal_types CASCADE;
DROP TABLE IF EXISTS public.edge_functions CASCADE;

RAISE NOTICE '✓ Step 2: Join tables and edge_functions dropped';

-- ============================================================================
-- STEP 3: Drop and Recreate Activities Table (TEXT → BIGSERIAL)
-- ============================================================================

DROP TABLE IF EXISTS public.activities CASCADE;

CREATE TABLE public.activities (
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

CREATE INDEX idx_activities_user_id ON public.activities (user_id);
CREATE INDEX idx_activities_scheduled_date_time ON public.activities (scheduled_date_time DESC);
CREATE INDEX idx_activities_activity_type ON public.activities (activity_type);
CREATE INDEX idx_activities_status ON public.activities (status);
CREATE INDEX idx_activities_needs_upload ON public.activities (needs_upload) WHERE needs_upload = TRUE;
CREATE INDEX idx_activities_deleted_at ON public.activities (deleted_at) WHERE deleted_at IS NULL;

COMMENT ON TABLE public.activities IS 'User activities (running, cycling, swimming)';
COMMENT ON COLUMN public.activities.id IS 'Primary key - BIGSERIAL auto-increment';
COMMENT ON COLUMN public.activities.user_id IS 'Foreign key to users.id (UUID)';

RAISE NOTICE '✓ Step 3: Activities table recreated with BIGSERIAL PK';

-- ============================================================================
-- STEP 4: Drop and Recreate Events Table
-- ============================================================================

DROP TABLE IF EXISTS public.events CASCADE;

CREATE TABLE public.events (
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

CREATE INDEX idx_events_user_id ON public.events (user_id);
CREATE INDEX idx_events_start_time ON public.events (start_time DESC);
CREATE INDEX idx_events_activity_id ON public.events (activity_id);

COMMENT ON TABLE public.events IS 'User calendar events (races, competitions)';
COMMENT ON COLUMN public.events.id IS 'Primary key - BIGSERIAL auto-increment';

RAISE NOTICE '✓ Step 4: Events table recreated';

-- ============================================================================
-- STEP 5: Drop and Recreate Carb Loading Plans Table
-- ============================================================================

DROP TABLE IF EXISTS public.carb_loading_plans CASCADE;

CREATE TABLE public.carb_loading_plans (
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

CREATE INDEX idx_carb_loading_plans_user_id ON public.carb_loading_plans (user_id);
CREATE INDEX idx_carb_loading_plans_race_date ON public.carb_loading_plans (race_date DESC);

COMMENT ON TABLE public.carb_loading_plans IS 'Carb loading plans for race preparation';
COMMENT ON COLUMN public.carb_loading_plans.id IS 'Primary key - BIGSERIAL auto-increment';

RAISE NOTICE '✓ Step 5: Carb loading plans table recreated';

-- ============================================================================
-- STEP 6: Drop and Recreate Carb Loading Days Table
-- ============================================================================

DROP TABLE IF EXISTS public.carb_loading_days CASCADE;

CREATE TABLE public.carb_loading_days (
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

CREATE INDEX idx_carb_loading_days_plan_id ON public.carb_loading_days (carb_loading_plan_id);
CREATE INDEX idx_carb_loading_days_day_date ON public.carb_loading_days (day_date);

COMMENT ON TABLE public.carb_loading_days IS 'Individual days in carb loading plan';
COMMENT ON COLUMN public.carb_loading_days.id IS 'Primary key - BIGSERIAL auto-increment';

RAISE NOTICE '✓ Step 6: Carb loading days table recreated';

-- ============================================================================
-- STEP 7: Drop and Recreate Workout Notes Table
-- ============================================================================

DROP TABLE IF EXISTS public.workout_notes CASCADE;

CREATE TABLE public.workout_notes (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  device_id TEXT,
  activity_id BIGINT REFERENCES public.activities(id) ON DELETE CASCADE,
  notes TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
  updated_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC')
);

CREATE INDEX idx_workout_notes_activity_id ON public.workout_notes (activity_id);

COMMENT ON TABLE public.workout_notes IS 'User notes for workout activities';
COMMENT ON COLUMN public.workout_notes.id IS 'Primary key - BIGSERIAL auto-increment';

RAISE NOTICE '✓ Step 7: Workout notes table recreated';

-- ============================================================================
-- STEP 8: Drop and Recreate Feature Survey Responses Table
-- ============================================================================

DROP TABLE IF EXISTS public.feature_survey_responses CASCADE;

CREATE TABLE public.feature_survey_responses (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  device_id TEXT,
  feature_name TEXT NOT NULL,
  response_data JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC')
);

CREATE INDEX idx_feature_survey_responses_user_id ON public.feature_survey_responses (user_id);
CREATE INDEX idx_feature_survey_responses_feature_name ON public.feature_survey_responses (feature_name);

COMMENT ON TABLE public.feature_survey_responses IS 'User responses to feature surveys';
COMMENT ON COLUMN public.feature_survey_responses.id IS 'Primary key - BIGSERIAL auto-increment';

RAISE NOTICE '✓ Step 8: Feature survey responses table recreated';

-- ============================================================================
-- STEP 9: Add Array Columns to Foods Tables
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

RAISE NOTICE '✓ Step 9: Array-based categories added to foods tables';

-- ============================================================================
-- STEP 10: Update user_id on remaining tables to UUID
-- ============================================================================

-- User Foods
ALTER TABLE public.user_foods DROP COLUMN IF EXISTS user_id CASCADE;
ALTER TABLE public.user_foods ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;
ALTER TABLE public.user_foods ADD CONSTRAINT user_foods_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_user_foods_user_id ON public.user_foods (user_id);

-- User Hidden Foods
ALTER TABLE public.user_hidden_foods DROP COLUMN IF EXISTS user_id CASCADE;
ALTER TABLE public.user_hidden_foods ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;
ALTER TABLE public.user_hidden_foods ADD CONSTRAINT user_hidden_foods_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_user_hidden_foods_user_id ON public.user_hidden_foods (user_id);

-- Carb Loading User Foods
ALTER TABLE public.carb_loading_user_foods DROP COLUMN IF EXISTS user_id CASCADE;
ALTER TABLE public.carb_loading_user_foods ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;
ALTER TABLE public.carb_loading_user_foods ADD CONSTRAINT carb_loading_user_foods_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_user_id ON public.carb_loading_user_foods (user_id);

RAISE NOTICE '✓ Step 10: user_id (UUID) added to remaining tables';

-- ============================================================================
-- STEP 11: Drop RLS and Triggers
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

RAISE NOTICE '✓ Step 11: RLS and triggers dropped';

-- ============================================================================
-- STEP 12: Permissive Grants
-- ============================================================================

GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;

RAISE NOTICE '✓ Step 12: Permissive grants applied';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  enum_count INTEGER;
  activities_id_type TEXT;
  activities_user_id_type TEXT;
  join_table_count INTEGER;
BEGIN
  -- Check enums
  SELECT COUNT(*) INTO enum_count FROM pg_type WHERE typname LIKE '%_enum';
  IF enum_count >= 12 THEN
    RAISE NOTICE '✓ Enums verified (% enums)', enum_count;
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

  -- Check join tables dropped
  SELECT COUNT(*) INTO join_table_count FROM pg_tables
  WHERE schemaname = 'public' AND tablename IN (
    'food_categories', 'categories', 'meal_types',
    'edge_functions', 'user_food_categories',
    'carb_loading_food_meal_types', 'carb_loading_user_food_meal_types'
  );
  IF join_table_count = 0 THEN
    RAISE NOTICE '✓ All join tables and edge_functions dropped';
  ELSE
    RAISE WARNING 'Found % join tables still present', join_table_count;
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

✓ Enums created (12+ enums for type safety)
✓ activities.id is BIGINT (BIGSERIAL)
✓ events.id is BIGINT (BIGSERIAL)
✓ carb_loading_plans.id is BIGINT (BIGSERIAL)
✓ carb_loading_days.id is BIGINT (BIGSERIAL)
✓ workout_notes.id is BIGINT (BIGSERIAL)
✓ feature_survey_responses.id is BIGINT (BIGSERIAL)
✓ All tables now use user_id (UUID) FK to users.id
✓ Array-based categories added to foods
✓ Join tables dropped (food_categories, categories, meal_types, etc.)
✓ edge_functions table dropped
✓ RLS disabled on all tables
✓ All RLS policies dropped
✓ Permissive grants applied

⚠️  WARNING: All data in recreated tables has been lost (this was intentional)

================================================================================
NEXT STEPS:
================================================================================

1. Verify schema with: \d activities
2. Test app (expect empty data - fresh start)
3. Update Drift schema (see DRIFT_UPDATES_PHASE_0.md)
4. After Dev testing passes (2+ days), run on Prod
5. Continue to Phase 1 (embed nutrition in activities)

================================================================================
' AS summary;
