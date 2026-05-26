-- ============================================================================
-- Migration: Complete Production → Development Schema Sync
-- Date: 2025-10-30
-- Purpose: Make PROD schema exactly match DEV schema
-- WARNING: This is a DESTRUCTIVE migration - backs up data where possible
-- ============================================================================

-- ============================================================================
-- PART 1: USERS TABLE - Add missing columns
-- ============================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS preferred_sports text[] DEFAULT ARRAY['running'::text],
  ADD COLUMN IF NOT EXISTS cycling_ftp_watts integer,
  ADD COLUMN IF NOT EXISTS prefers_cycling_power boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS swimming_css_seconds_per_100m integer,
  ADD COLUMN IF NOT EXISTS prefers_swimming_pace boolean DEFAULT false;

COMMENT ON COLUMN public.users.preferred_sports IS 'Array of preferred sports (running, cycling, swimming)';
COMMENT ON COLUMN public.users.cycling_ftp_watts IS 'Functional Threshold Power for cycling';
COMMENT ON COLUMN public.users.swimming_css_seconds_per_100m IS 'Critical Swim Speed in seconds per 100m';

-- ============================================================================
-- PART 2: FOODS TABLE - Add suitability columns
-- ============================================================================

ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS cycling_suitable boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS swimming_suitable boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS suitable_for_activities jsonb;

COMMENT ON COLUMN public.foods.cycling_suitable IS 'Whether food is suitable for cycling activities';
COMMENT ON COLUMN public.foods.swimming_suitable IS 'Whether food is suitable for swimming activities';
COMMENT ON COLUMN public.foods.suitable_for_activities IS 'JSON object mapping activity types to suitability';

-- ============================================================================
-- PART 3: USER_FOODS TABLE - Add suitability columns
-- ============================================================================

ALTER TABLE public.user_foods
  ADD COLUMN IF NOT EXISTS cycling_suitable boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS swimming_suitable boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS suitable_for_activities jsonb;

-- ============================================================================
-- PART 4: ACTIVITIES TABLE - Complete restructure
-- ============================================================================

-- Add user_id column (keep device_id for now for data migration)
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS user_id text;

-- Backfill user_id from device_id using users table
UPDATE public.activities a
SET user_id = u.id::text
FROM public.users u
WHERE a.device_id = u.device_id;

-- Add all missing DEV columns
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS scheduled_date_time timestamp,
  ADD COLUMN IF NOT EXISTS pace_target_minutes_per_mile real,
  ADD COLUMN IF NOT EXISTS intensity_level text;

-- Migrate data from PROD column names to DEV column names
UPDATE public.activities
SET
  scheduled_date_time = scheduled_date,
  pace_target_minutes_per_mile = pace_minutes_per_mile,
  intensity_level = CASE
    WHEN intensity_target = 'easy' THEN 'easy'
    WHEN intensity_target = 'moderate' THEN 'moderate'
    WHEN intensity_target = 'hard' THEN 'hard'
    WHEN intensity_target = 'race' THEN 'race'
    ELSE intensity_level
  END,
  title = COALESCE(
    CASE activity_type
      WHEN 'running' THEN 'Run - ' || COALESCE(distance_miles::text || ' mi', duration_minutes::text || ' min')
      WHEN 'event' THEN 'Event'
      ELSE activity_type
    END,
    'Activity'
  )
WHERE scheduled_date_time IS NULL OR pace_target_minutes_per_mile IS NULL OR title IS NULL;

-- Add completion tracking columns
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS completed_at timestamp,
  ADD COLUMN IF NOT EXISTS completion_rating integer,
  ADD COLUMN IF NOT EXISTS completion_notes text,
  ADD COLUMN IF NOT EXISTS actual_distance_miles real,
  ADD COLUMN IF NOT EXISTS actual_duration_minutes integer;

-- Add reminder columns
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS reminder_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS reminder_days_before integer,
  ADD COLUMN IF NOT EXISTS reminder_time_of_day text,
  ADD COLUMN IF NOT EXISTS reminder_recurring boolean DEFAULT false;

-- Add soft delete and notes
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS deleted_at timestamp,
  ADD COLUMN IF NOT EXISTS notes text;

-- Update constraints
ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activity_type_check;

ALTER TABLE public.activities
  ADD CONSTRAINT activity_type_check
  CHECK (activity_type IN ('running', 'event'));

ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS intensity_check;

ALTER TABLE public.activities
  ADD CONSTRAINT intensity_check
  CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race'));

ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS rating_check;

ALTER TABLE public.activities
  ADD CONSTRAINT rating_check
  CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5));

-- Make user_id NOT NULL after backfill (if there's data)
-- ALTER TABLE public.activities ALTER COLUMN user_id SET NOT NULL;

-- Make title and scheduled_date_time NOT NULL (DEV requirement)
ALTER TABLE public.activities ALTER COLUMN title SET NOT NULL;
ALTER TABLE public.activities ALTER COLUMN scheduled_date_time SET NOT NULL;

-- Update RLS policies to use user_id instead of device_id
DROP POLICY IF EXISTS "Users can access their own activities" ON public.activities;

CREATE POLICY activities_select_policy ON public.activities
  AS PERMISSIVE FOR SELECT
  USING (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_insert_policy ON public.activities
  AS PERMISSIVE FOR INSERT
  WITH CHECK (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_update_policy ON public.activities
  AS PERMISSIVE FOR UPDATE
  USING (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_delete_policy ON public.activities
  AS PERMISSIVE FOR DELETE
  USING (user_id = current_setting('app.user_id', true));

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_activities_user ON public.activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_scheduled ON public.activities(scheduled_date_time);
CREATE INDEX IF NOT EXISTS idx_activities_type ON public.activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_status ON public.activities(status);

-- Update table comment
COMMENT ON TABLE public.activities IS 'All calendar entries including workouts and events';
COMMENT ON COLUMN public.activities.activity_type IS 'Type: running (workout) or event (race)';
COMMENT ON COLUMN public.activities.status IS 'Current status: planned, in_progress, completed, skipped';

-- ============================================================================
-- PART 5: EVENTS TABLE - Complete restructure
-- ============================================================================

-- Backup existing events data
CREATE TEMP TABLE events_backup AS
SELECT * FROM public.events;

-- Drop and recreate events table with DEV schema
DROP TABLE IF EXISTS public.events CASCADE;

CREATE TABLE public.events (
  id text NOT NULL PRIMARY KEY,
  activity_id text NOT NULL UNIQUE REFERENCES public.activities(id) ON DELETE CASCADE,
  event_type text NOT NULL
    CONSTRAINT event_type_check
    CHECK (event_type IN ('marathon', 'half_marathon', '10k', '5k', 'ultra_50k', 'ultra_50m', 'ultra_100k', 'ultra_100m', 'custom')),
  event_subtype text,
  event_name text,
  location text,
  registration_url text,
  start_time text,
  goal_time_minutes integer,
  goal_pace_minutes_per_mile real,
  predicted_finish_time_minutes integer,
  has_carb_loading boolean DEFAULT false,
  carb_loading_days integer
    CONSTRAINT carb_days_check
    CHECK (carb_loading_days IS NULL OR carb_loading_days IN (1, 2, 3, 7)),
  carb_loading_start_date timestamp,
  bib_number text,
  wave_start_time text,
  packet_pickup_info text,
  actual_finish_time_minutes integer,
  final_placement integer,
  age_group_placement integer,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp DEFAULT CURRENT_TIMESTAMP,
  has_nutrition_plan boolean DEFAULT false
);

COMMENT ON TABLE public.events IS 'Specialized event data for races and competitions';
COMMENT ON COLUMN public.events.activity_id IS 'One-to-one link to activities table';
COMMENT ON COLUMN public.events.has_carb_loading IS 'Whether this event has an associated carb loading plan';
COMMENT ON COLUMN public.events.has_nutrition_plan IS 'Indicates whether this event has an associated nutrition plan (via activities.id -> nutrition_plans.activity_id)';

-- Create indexes
CREATE INDEX idx_events_activity ON public.events(activity_id);
CREATE INDEX idx_events_type ON public.events(event_type);
CREATE INDEX idx_events_carb_loading ON public.events(has_carb_loading) WHERE has_carb_loading = true;

-- Migrate data from backup (best effort - many columns won't exist)
INSERT INTO public.events (
  id,
  activity_id,
  event_type,
  event_name,
  has_carb_loading,
  has_nutrition_plan,
  created_at,
  updated_at
)
SELECT
  eb.id,
  eb.activity_id,
  'custom' as event_type,  -- default since PROD doesn't have this
  eb.event_name,
  COALESCE(eb.has_carb_loading, false),
  COALESCE(eb.has_nutrition_plan, false),
  eb.created_at,
  eb.updated_at
FROM events_backup eb
WHERE eb.activity_id IN (SELECT id FROM public.activities);

-- Create RLS policies
CREATE POLICY events_select_policy ON public.events
  AS PERMISSIVE FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = events.activity_id
    AND activities.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY events_insert_policy ON public.events
  AS PERMISSIVE FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = events.activity_id
    AND activities.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY events_update_policy ON public.events
  AS PERMISSIVE FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = events.activity_id
    AND activities.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY events_delete_policy ON public.events
  AS PERMISSIVE FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = events.activity_id
    AND activities.user_id = current_setting('app.user_id', true)
  ));

-- Enable RLS
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

-- Grants
GRANT ALL ON public.events TO anon, authenticated, service_role;

-- ============================================================================
-- PART 6: NUTRITION_PLANS TABLE - Add FK constraint
-- ============================================================================

-- Add FK constraint to activities (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_nutrition_plans_activity_id'
    AND table_name = 'nutrition_plans'
  ) THEN
    ALTER TABLE public.nutrition_plans
    ADD CONSTRAINT fk_nutrition_plans_activity_id
    FOREIGN KEY (activity_id)
    REFERENCES public.activities(id)
    ON DELETE SET NULL;
  END IF;
END $$;

-- Add index
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_activity_id ON public.nutrition_plans(activity_id);

-- Remove user_id column if exists (not in DEV schema)
ALTER TABLE public.nutrition_plans DROP COLUMN IF EXISTS user_id;

-- ============================================================================
-- PART 7: CARB_LOADING_PLANS TABLE - Restructure
-- ============================================================================

CREATE TEMP TABLE carb_plans_backup AS
SELECT * FROM public.carb_loading_plans;

DROP TABLE IF EXISTS public.carb_loading_plans CASCADE;

CREATE TABLE public.carb_loading_plans (
  id text NOT NULL PRIMARY KEY,
  event_id text REFERENCES public.events(id) ON DELETE CASCADE,
  user_id text NOT NULL,
  total_days integer NOT NULL
    CONSTRAINT total_days_check CHECK (total_days IN (1, 2, 3, 7)),
  start_date timestamp NOT NULL,
  end_date timestamp NOT NULL,
  daily_carb_target_grams integer NOT NULL,
  daily_calorie_target integer,
  generated_at timestamp NOT NULL,
  algorithm_version text DEFAULT 'v1.0',
  adherence_score real
    CONSTRAINT adherence_check CHECK (adherence_score IS NULL OR (adherence_score >= 0.0 AND adherence_score <= 1.0)),
  completed_at timestamp
);

COMMENT ON TABLE public.carb_loading_plans IS 'Carb loading plans linked to specific events';
COMMENT ON COLUMN public.carb_loading_plans.event_id IS 'FOREIGN KEY to events.id. Nullable to support standalone carb loading plans not tied to specific events. Multiple plans can share the same event_id.';
COMMENT ON COLUMN public.carb_loading_plans.adherence_score IS '0.0 to 1.0 based on logged meals';

CREATE INDEX idx_carb_plans_event ON public.carb_loading_plans(event_id);
CREATE INDEX idx_carb_plans_user ON public.carb_loading_plans(user_id);
CREATE INDEX idx_carb_plans_dates ON public.carb_loading_plans(start_date, end_date);

-- Migrate data (best effort)
INSERT INTO public.carb_loading_plans (
  id, event_id, user_id, total_days, start_date, end_date,
  daily_carb_target_grams, daily_calorie_target, generated_at, algorithm_version
)
SELECT
  cpb.id,
  cpb.event_id,
  COALESCE(u.id::text, 'unknown') as user_id,
  CASE
    WHEN (cpb.end_date - cpb.start_date) <= INTERVAL '1 day' THEN 1
    WHEN (cpb.end_date - cpb.start_date) <= INTERVAL '2 days' THEN 2
    WHEN (cpb.end_date - cpb.start_date) <= INTERVAL '3 days' THEN 3
    ELSE 7
  END as total_days,
  cpb.start_date,
  cpb.end_date,
  400 as daily_carb_target_grams,  -- default estimate
  2000 as daily_calorie_target,     -- default estimate
  cpb.created_at as generated_at,
  'v1.0' as algorithm_version
FROM carb_plans_backup cpb
LEFT JOIN public.users u ON cpb.device_id = u.device_id
WHERE cpb.event_id IN (SELECT id FROM public.events);

-- RLS policies
CREATE POLICY carb_plans_select_policy ON public.carb_loading_plans
  AS PERMISSIVE FOR SELECT
  USING (user_id = current_setting('app.user_id', true));

CREATE POLICY carb_plans_insert_policy ON public.carb_loading_plans
  AS PERMISSIVE FOR INSERT
  WITH CHECK (user_id = current_setting('app.user_id', true));

CREATE POLICY carb_plans_update_policy ON public.carb_loading_plans
  AS PERMISSIVE FOR UPDATE
  USING (user_id = current_setting('app.user_id', true));

CREATE POLICY carb_plans_delete_policy ON public.carb_loading_plans
  AS PERMISSIVE FOR DELETE
  USING (user_id = current_setting('app.user_id', true));

ALTER TABLE public.carb_loading_plans ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.carb_loading_plans TO anon, authenticated, service_role;

-- ============================================================================
-- PART 8: CARB_LOADING_DAYS TABLE - Restructure
-- ============================================================================

CREATE TEMP TABLE carb_days_backup AS
SELECT * FROM public.carb_loading_days;

DROP TABLE IF EXISTS public.carb_loading_days CASCADE;

CREATE TABLE public.carb_loading_days (
  id text NOT NULL PRIMARY KEY,
  carb_loading_plan_id text NOT NULL REFERENCES public.carb_loading_plans(id) ON DELETE CASCADE,
  plan_date timestamp NOT NULL,
  day_number integer NOT NULL CONSTRAINT day_number_check CHECK (day_number > 0),
  carb_target_grams integer NOT NULL CONSTRAINT carb_target_check CHECK (carb_target_grams > 0),
  calorie_target integer,
  meal_count integer DEFAULT 6 CONSTRAINT meal_count_check CHECK (meal_count > 0),
  breakfast_percent real DEFAULT 0.25 CONSTRAINT breakfast_percent_check CHECK (breakfast_percent >= 0.0 AND breakfast_percent <= 1.0),
  morning_snack_percent real DEFAULT 0.10 CONSTRAINT morning_snack_percent_check CHECK (morning_snack_percent >= 0.0 AND morning_snack_percent <= 1.0),
  lunch_percent real DEFAULT 0.25 CONSTRAINT lunch_percent_check CHECK (lunch_percent >= 0.0 AND lunch_percent <= 1.0),
  afternoon_snack_percent real DEFAULT 0.15 CONSTRAINT afternoon_snack_percent_check CHECK (afternoon_snack_percent >= 0.0 AND afternoon_snack_percent <= 1.0),
  dinner_percent real DEFAULT 0.20 CONSTRAINT dinner_percent_check CHECK (dinner_percent >= 0.0 AND dinner_percent <= 1.0),
  evening_snack_percent real DEFAULT 0.05 CONSTRAINT evening_snack_percent_check CHECK (evening_snack_percent >= 0.0 AND evening_snack_percent <= 1.0),
  logged_carbs_grams integer DEFAULT 0 CONSTRAINT logged_carbs_check CHECK (logged_carbs_grams >= 0),
  logged_calories integer DEFAULT 0 CONSTRAINT logged_calories_check CHECK (logged_calories >= 0),
  completed boolean DEFAULT false,
  carb_protocol_g_per_kg real DEFAULT 8.0 NOT NULL,
  UNIQUE (carb_loading_plan_id, plan_date)
);

COMMENT ON TABLE public.carb_loading_days IS 'Individual day entries within carb loading plans';
COMMENT ON COLUMN public.carb_loading_days.day_number IS '1, 2, 3, etc. (last number = race day - 1)';
COMMENT ON COLUMN public.carb_loading_days.meal_count IS 'Default 6: breakfast, snack, lunch, snack, dinner, evening';
COMMENT ON COLUMN public.carb_loading_days.carb_protocol_g_per_kg IS 'Carbohydrate protocol in grams per kilogram of bodyweight (e.g., 8.0 for 8g/kg)';

CREATE INDEX idx_carb_days_plan ON public.carb_loading_days(carb_loading_plan_id);
CREATE INDEX idx_carb_days_date ON public.carb_loading_days(plan_date);
CREATE INDEX idx_carb_days_completed ON public.carb_loading_days(completed);

-- Migrate data (best effort)
INSERT INTO public.carb_loading_days (
  id, carb_loading_plan_id, plan_date, day_number, carb_target_grams,
  calorie_target, meal_count, carb_protocol_g_per_kg
)
SELECT
  cdb.id,
  cdb.plan_id as carb_loading_plan_id,
  cdb.date as plan_date,
  COALESCE(cdb.day_number, 1) as day_number,
  COALESCE(cdb.target_carbs_grams, 400) as carb_target_grams,
  2000 as calorie_target,
  COALESCE(cdb.meal_count, 6) as meal_count,
  COALESCE(cdb.carb_protocol_g_per_kg, 8.0) as carb_protocol_g_per_kg
FROM carb_days_backup cdb
WHERE cdb.plan_id IN (SELECT id FROM public.carb_loading_plans);

-- RLS policies
CREATE POLICY carb_days_select_policy ON public.carb_loading_days
  AS PERMISSIVE FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
    AND carb_loading_plans.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY carb_days_insert_policy ON public.carb_loading_days
  AS PERMISSIVE FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
    AND carb_loading_plans.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY carb_days_update_policy ON public.carb_loading_days
  AS PERMISSIVE FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
    AND carb_loading_plans.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY carb_days_delete_policy ON public.carb_loading_days
  AS PERMISSIVE FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
    AND carb_loading_plans.user_id = current_setting('app.user_id', true)
  ));

ALTER TABLE public.carb_loading_days ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.carb_loading_days TO anon, authenticated, service_role;

-- ============================================================================
-- PART 9: MEAL_TYPES TABLE - Change ID type
-- ============================================================================

CREATE TEMP TABLE meal_types_backup AS
SELECT * FROM public.meal_types;

DROP TABLE IF EXISTS public.meal_types CASCADE;

CREATE TABLE public.meal_types (
  id integer NOT NULL PRIMARY KEY,
  name text NOT NULL UNIQUE,
  display_name text NOT NULL
);

COMMENT ON TABLE public.meal_types IS 'Meal categories for carb loading feature (breakfast, morning_snack, lunch, afternoon_snack, dinner, evening_snack)';
COMMENT ON COLUMN public.meal_types.id IS 'Primary key (1=breakfast, 2=lunch, 3=dinner, 4=snacks [deprecated], 5=morning_snack, 6=afternoon_snack, 7=evening_snack)';
COMMENT ON COLUMN public.meal_types.name IS 'Internal name (lowercase, underscore-separated)';
COMMENT ON COLUMN public.meal_types.display_name IS 'Display name for UI (title case)';

-- Seed data
INSERT INTO public.meal_types (id, name, display_name) VALUES
  (1, 'breakfast', 'Breakfast'),
  (2, 'lunch', 'Lunch'),
  (3, 'dinner', 'Dinner'),
  (5, 'morning_snack', 'Morning Snack'),
  (6, 'afternoon_snack', 'Afternoon Snack'),
  (7, 'evening_snack', 'Evening Snack')
ON CONFLICT (id) DO NOTHING;

CREATE POLICY meal_types_public_read ON public.meal_types
  AS PERMISSIVE FOR SELECT USING (true);

ALTER TABLE public.meal_types ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.meal_types TO anon, authenticated, service_role;

-- ============================================================================
-- PART 10: CARB_LOADING_FOODS TABLE - Change to UUID
-- ============================================================================

-- Note: This will lose data - can't easily convert TEXT IDs to UUIDs
DROP TABLE IF EXISTS public.carb_loading_foods CASCADE;

CREATE TABLE public.carb_loading_foods (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  name text NOT NULL,
  display_name text NOT NULL,
  display_name_plural text,
  carbs_per_serving real NOT NULL CONSTRAINT carbs_positive CHECK (carbs_per_serving > 0),
  image_address text,
  is_default boolean DEFAULT true,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.carb_loading_foods IS 'Global default carb loading foods (cereal, pasta, etc.) - pre-seeded';

CREATE INDEX idx_carb_loading_foods_name ON public.carb_loading_foods(name);
CREATE INDEX idx_carb_loading_foods_default ON public.carb_loading_foods(is_default);

CREATE POLICY carb_loading_foods_public_read ON public.carb_loading_foods
  AS PERMISSIVE FOR SELECT USING (true);

ALTER TABLE public.carb_loading_foods ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.carb_loading_foods TO anon, authenticated, service_role;

-- ============================================================================
-- PART 11: CARB_LOADING_USER_FOODS TABLE - Change to UUID
-- ============================================================================

DROP TABLE IF EXISTS public.carb_loading_user_foods CASCADE;

CREATE TABLE public.carb_loading_user_foods (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  device_id text NOT NULL,
  client_food_id text,
  name text NOT NULL,
  display_name text NOT NULL,
  display_name_plural text,
  carbs_per_serving real NOT NULL CONSTRAINT carbs_positive CHECK (carbs_per_serving > 0),
  image_address text,
  barcode text,
  source_food_id uuid REFERENCES public.foods(id),
  source_user_food_id uuid REFERENCES public.user_foods(id),
  is_deleted boolean DEFAULT false,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.carb_loading_user_foods IS 'User-created carb loading foods from scanning, importing, or manual entry';

CREATE INDEX idx_carb_loading_user_foods_device ON public.carb_loading_user_foods(device_id);
CREATE INDEX idx_carb_loading_user_foods_deleted ON public.carb_loading_user_foods(is_deleted);
CREATE INDEX idx_carb_loading_user_foods_barcode ON public.carb_loading_user_foods(barcode) WHERE barcode IS NOT NULL;

CREATE POLICY carb_loading_user_foods_device_read ON public.carb_loading_user_foods
  AS PERMISSIVE FOR SELECT
  USING (device_id = current_setting('app.device_id', true));

CREATE POLICY carb_loading_user_foods_device_insert ON public.carb_loading_user_foods
  AS PERMISSIVE FOR INSERT
  WITH CHECK (device_id = current_setting('app.device_id', true));

CREATE POLICY carb_loading_user_foods_device_update ON public.carb_loading_user_foods
  AS PERMISSIVE FOR UPDATE
  USING (device_id = current_setting('app.device_id', true));

CREATE POLICY carb_loading_user_foods_device_delete ON public.carb_loading_user_foods
  AS PERMISSIVE FOR DELETE
  USING (device_id = current_setting('app.device_id', true));

ALTER TABLE public.carb_loading_user_foods ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.carb_loading_user_foods TO anon, authenticated, service_role;

-- ============================================================================
-- PART 12: Junction tables for meal types
-- ============================================================================

DROP TABLE IF EXISTS public.carb_loading_food_meal_types CASCADE;

CREATE TABLE public.carb_loading_food_meal_types (
  carb_loading_food_id uuid NOT NULL REFERENCES public.carb_loading_foods(id) ON DELETE CASCADE,
  meal_type_id integer NOT NULL REFERENCES public.meal_types(id),
  PRIMARY KEY (carb_loading_food_id, meal_type_id)
);

COMMENT ON TABLE public.carb_loading_food_meal_types IS 'Links global carb loading foods to meal types (e.g., Cereal → Breakfast)';

CREATE INDEX idx_carb_food_meal_types_food ON public.carb_loading_food_meal_types(carb_loading_food_id);
CREATE INDEX idx_carb_food_meal_types_meal ON public.carb_loading_food_meal_types(meal_type_id);

CREATE POLICY carb_loading_food_meal_types_public_read ON public.carb_loading_food_meal_types
  AS PERMISSIVE FOR SELECT USING (true);

ALTER TABLE public.carb_loading_food_meal_types ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.carb_loading_food_meal_types TO anon, authenticated, service_role;

-- User food meal types
DROP TABLE IF EXISTS public.carb_loading_user_food_meal_types CASCADE;

CREATE TABLE public.carb_loading_user_food_meal_types (
  carb_loading_user_food_id uuid NOT NULL
    REFERENCES public.carb_loading_user_foods(id) ON DELETE CASCADE,
  meal_type_id integer NOT NULL REFERENCES public.meal_types(id),
  PRIMARY KEY (carb_loading_user_food_id, meal_type_id)
);

COMMENT ON TABLE public.carb_loading_user_food_meal_types IS 'Links user carb loading foods to meal types (e.g., "My Pasta" → Lunch, Dinner)';

CREATE INDEX idx_carb_user_food_meal_types_food ON public.carb_loading_user_food_meal_types(carb_loading_user_food_id);
CREATE INDEX idx_carb_user_food_meal_types_meal ON public.carb_loading_user_food_meal_types(meal_type_id);

CREATE POLICY carb_loading_user_food_meal_types_device_read ON public.carb_loading_user_food_meal_types
  AS PERMISSIVE FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM carb_loading_user_foods
    WHERE carb_loading_user_foods.id = carb_loading_user_food_meal_types.carb_loading_user_food_id
    AND carb_loading_user_foods.device_id = current_setting('app.device_id', true)
  ));

CREATE POLICY carb_loading_user_food_meal_types_device_insert ON public.carb_loading_user_food_meal_types
  AS PERMISSIVE FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM carb_loading_user_foods
    WHERE carb_loading_user_foods.id = carb_loading_user_food_meal_types.carb_loading_user_food_id
    AND carb_loading_user_foods.device_id = current_setting('app.device_id', true)
  ));

CREATE POLICY carb_loading_user_food_meal_types_device_delete ON public.carb_loading_user_food_meal_types
  AS PERMISSIVE FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM carb_loading_user_foods
    WHERE carb_loading_user_foods.id = carb_loading_user_food_meal_types.carb_loading_user_food_id
    AND carb_loading_user_foods.device_id = current_setting('app.device_id', true)
  ));

ALTER TABLE public.carb_loading_user_food_meal_types ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.carb_loading_user_food_meal_types TO anon, authenticated, service_role;

-- ============================================================================
-- PART 13: CARB_LOADING_DAY_MEALS TABLE - Fix structure
-- ============================================================================

DROP TABLE IF EXISTS public.carb_loading_day_meals CASCADE;

CREATE TABLE public.carb_loading_day_meals (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  carb_loading_day_id text NOT NULL REFERENCES public.carb_loading_days(id) ON DELETE CASCADE,
  meal_type_id integer NOT NULL REFERENCES public.meal_types(id),
  carb_loading_food_id uuid REFERENCES public.carb_loading_foods(id),
  carb_loading_user_food_id uuid REFERENCES public.carb_loading_user_foods(id),
  food_display_name text,
  quantity integer DEFAULT 1 CONSTRAINT quantity_positive CHECK (quantity > 0),
  carbs_consumed real NOT NULL CONSTRAINT carbs_positive CHECK (carbs_consumed >= 0),
  created_at timestamp DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT one_food_type CHECK (
    (carb_loading_food_id IS NOT NULL AND carb_loading_user_food_id IS NULL) OR
    (carb_loading_food_id IS NULL AND carb_loading_user_food_id IS NOT NULL)
  )
);

COMMENT ON TABLE public.carb_loading_day_meals IS 'Actual food selections per meal per day (e.g., Day -2, Breakfast: 2x Cereal, 1x Banana)';
COMMENT ON COLUMN public.carb_loading_day_meals.quantity IS 'Number of servings';
COMMENT ON COLUMN public.carb_loading_day_meals.carbs_consumed IS 'Calculated: quantity * carbs_per_serving';

CREATE INDEX idx_carb_day_meals_day ON public.carb_loading_day_meals(carb_loading_day_id);
CREATE INDEX idx_carb_day_meals_meal_type ON public.carb_loading_day_meals(meal_type_id);
CREATE INDEX idx_carb_day_meals_food ON public.carb_loading_day_meals(carb_loading_food_id) WHERE carb_loading_food_id IS NOT NULL;
CREATE INDEX idx_carb_day_meals_user_food ON public.carb_loading_day_meals(carb_loading_user_food_id) WHERE carb_loading_user_food_id IS NOT NULL;

CREATE POLICY carb_loading_day_meals_device_read ON public.carb_loading_day_meals
  AS PERMISSIVE FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
    AND p.user_id = current_setting('app.device_id', true)
  ));

CREATE POLICY carb_loading_day_meals_device_insert ON public.carb_loading_day_meals
  AS PERMISSIVE FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
    AND p.user_id = current_setting('app.device_id', true)
  ));

CREATE POLICY carb_loading_day_meals_device_update ON public.carb_loading_day_meals
  AS PERMISSIVE FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
    AND p.user_id = current_setting('app.device_id', true)
  ));

CREATE POLICY carb_loading_day_meals_device_delete ON public.carb_loading_day_meals
  AS PERMISSIVE FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
    AND p.user_id = current_setting('app.device_id', true)
  ));

ALTER TABLE public.carb_loading_day_meals ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.carb_loading_day_meals TO anon, authenticated, service_role;

-- ============================================================================
-- PART 14: ACTIVITY_COMPLETIONS TABLE - Fix structure
-- ============================================================================

DROP TABLE IF EXISTS public.activity_completions CASCADE;

CREATE TABLE public.activity_completions (
  id text NOT NULL PRIMARY KEY,
  activity_id text NOT NULL UNIQUE REFERENCES public.activities(id) ON DELETE CASCADE,
  completed_at timestamp NOT NULL,
  actual_distance_miles real,
  actual_duration_minutes integer,
  average_pace_minutes_per_mile real,
  completion_rating integer CONSTRAINT rating_check CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5)),
  completion_notes text,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.activity_completions IS 'Completion records for activities';
COMMENT ON COLUMN public.activity_completions.activity_id IS 'One-to-one link to activities table';

CREATE INDEX idx_activity_completions_activity ON public.activity_completions(activity_id);
CREATE INDEX idx_activity_completions_date ON public.activity_completions(completed_at);

CREATE POLICY activity_completions_select_policy ON public.activity_completions
  AS PERMISSIVE FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = activity_completions.activity_id
    AND activities.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY activity_completions_insert_policy ON public.activity_completions
  AS PERMISSIVE FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = activity_completions.activity_id
    AND activities.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY activity_completions_update_policy ON public.activity_completions
  AS PERMISSIVE FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = activity_completions.activity_id
    AND activities.user_id = current_setting('app.user_id', true)
  ));

CREATE POLICY activity_completions_delete_policy ON public.activity_completions
  AS PERMISSIVE FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = activity_completions.activity_id
    AND activities.user_id = current_setting('app.user_id', true)
  ));

ALTER TABLE public.activity_completions ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.activity_completions TO anon, authenticated, service_role;

-- ============================================================================
-- PART 15: MACRO_TARGETS_TABLE - Complete restructure
-- ============================================================================

-- Backup and drop
DROP TABLE IF EXISTS public.macro_targets_table CASCADE;

CREATE TABLE public.macro_targets_table (
  id text NOT NULL PRIMARY KEY
    CONSTRAINT macro_targets_table_id_check CHECK (length(id) >= 1 AND length(id) <= 50),
  pre_run_carbs_g numeric NOT NULL CONSTRAINT check_pre_run_carbs_positive CHECK (pre_run_carbs_g >= 0),
  pre_run_protein_g numeric NOT NULL CONSTRAINT check_pre_run_protein_positive CHECK (pre_run_protein_g >= 0),
  pre_run_fat_cap_g numeric NOT NULL CONSTRAINT check_pre_run_fat_positive CHECK (pre_run_fat_cap_g >= 0),
  pre_run_fluids_ml numeric NOT NULL CONSTRAINT check_pre_run_fluids_positive CHECK (pre_run_fluids_ml >= 0),
  pre_run_sodium_mg numeric NOT NULL CONSTRAINT check_pre_run_sodium_positive CHECK (pre_run_sodium_mg >= 0),
  during_carb_rate_g_per_h numeric NOT NULL CONSTRAINT check_during_carb_rate_positive CHECK (during_carb_rate_g_per_h >= 0),
  during_carb_total_g numeric NOT NULL CONSTRAINT check_during_carb_total_positive CHECK (during_carb_total_g >= 0),
  during_fluid_rate_ml_per_h numeric NOT NULL CONSTRAINT check_during_fluid_rate_positive CHECK (during_fluid_rate_ml_per_h >= 0),
  during_fluid_total_ml numeric NOT NULL CONSTRAINT check_during_fluid_total_positive CHECK (during_fluid_total_ml >= 0),
  during_sodium_rate_mg_per_h numeric NOT NULL CONSTRAINT check_during_sodium_rate_positive CHECK (during_sodium_rate_mg_per_h >= 0),
  during_sodium_total_mg numeric NOT NULL CONSTRAINT check_during_sodium_total_positive CHECK (during_sodium_total_mg >= 0),
  during_mass_norm_rate_g_per_h numeric,
  post_run_carbs_g numeric NOT NULL CONSTRAINT check_post_run_carbs_positive CHECK (post_run_carbs_g >= 0),
  post_run_protein_g numeric NOT NULL CONSTRAINT check_post_run_protein_positive CHECK (post_run_protein_g >= 0),
  post_run_fluids_ml numeric NOT NULL CONSTRAINT check_post_run_fluids_positive CHECK (post_run_fluids_ml >= 0),
  post_run_sodium_mg numeric NOT NULL CONSTRAINT check_post_run_sodium_positive CHECK (post_run_sodium_mg >= 0),
  distance_mi numeric NOT NULL CONSTRAINT check_distance_positive CHECK (distance_mi > 0),
  duration_h numeric NOT NULL CONSTRAINT check_duration_positive CHECK (duration_h > 0),
  pace_min_per_mile numeric NOT NULL CONSTRAINT check_pace_positive CHECK (pace_min_per_mile > 0),
  calories_gross_kcal numeric NOT NULL CONSTRAINT check_calories_positive CHECK (calories_gross_kcal >= 0),
  met numeric NOT NULL CONSTRAINT check_met_positive CHECK (met > 0),
  calculation_rule text NOT NULL,
  timestamp timestamp NOT NULL,
  is_user_modified boolean DEFAULT false NOT NULL,
  modified_fields text DEFAULT '' NOT NULL
);

COMMENT ON TABLE public.macro_targets_table IS 'Calculated nutrition targets for running sessions (26 columns)';

CREATE INDEX idx_macro_targets_timestamp ON public.macro_targets_table(timestamp);
CREATE INDEX idx_macro_targets_distance ON public.macro_targets_table(distance_mi);

CREATE POLICY macro_targets_public_read ON public.macro_targets_table
  AS PERMISSIVE FOR SELECT USING (true);

CREATE POLICY macro_targets_authenticated_insert ON public.macro_targets_table
  AS PERMISSIVE FOR INSERT WITH CHECK (true);

CREATE POLICY macro_targets_authenticated_update ON public.macro_targets_table
  AS PERMISSIVE FOR UPDATE USING (true);

ALTER TABLE public.macro_targets_table ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.macro_targets_table TO anon, authenticated, service_role;

-- ============================================================================
-- PART 16: WORKOUT_NOTES TABLE - Fix structure
-- ============================================================================

DROP TABLE IF EXISTS public.workout_notes CASCADE;

CREATE TABLE public.workout_notes (
  id text NOT NULL PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plan_id text,
  note_text text NOT NULL,
  rating integer CONSTRAINT workout_notes_rating_check CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5)),
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);

COMMENT ON TABLE public.workout_notes IS 'User workout journal entries with optional ratings';
COMMENT ON COLUMN public.workout_notes.user_id IS 'References users.id (not device_id)';

CREATE INDEX idx_workout_notes_user ON public.workout_notes(user_id);
CREATE INDEX idx_workout_notes_plan ON public.workout_notes(plan_id) WHERE plan_id IS NOT NULL;
CREATE INDEX idx_workout_notes_created ON public.workout_notes(created_at);

CREATE POLICY workout_notes_user_read ON public.workout_notes
  AS PERMISSIVE FOR SELECT
  USING (user_id = (current_setting('app.user_id', true))::uuid);

CREATE POLICY workout_notes_user_insert ON public.workout_notes
  AS PERMISSIVE FOR INSERT
  WITH CHECK (user_id = (current_setting('app.user_id', true))::uuid);

CREATE POLICY workout_notes_user_update ON public.workout_notes
  AS PERMISSIVE FOR UPDATE
  USING (user_id = (current_setting('app.user_id', true))::uuid);

CREATE POLICY workout_notes_user_delete ON public.workout_notes
  AS PERMISSIVE FOR DELETE
  USING (user_id = (current_setting('app.user_id', true))::uuid);

ALTER TABLE public.workout_notes ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.workout_notes TO anon, authenticated, service_role;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Production schema now matches Development schema';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'IMPORTANT: Update your edge functions to use:';
  RAISE NOTICE '  - user_id instead of device_id in activities table';
  RAISE NOTICE '  - New events table structure';
  RAISE NOTICE '  - New macro_targets_table structure';
  RAISE NOTICE '========================================';
END $$;
