-- =====================================================
-- Schema Sync Migration: Resume from Step 4
-- =====================================================
-- Purpose: Continue migration from where it failed
-- Date: 2025-11-06
-- Status: SAFE TO RUN - Picks up from Step 4 onwards
--
-- This script assumes Steps 1-3 completed successfully:
-- ✅ Step 1-2: Users table columns added
-- ✅ Step 3: activity_type constraint updated, sport_type column added
--
-- Now continuing from Step 4...
-- =====================================================

-- =====================================================
-- STEP 4: Add cycling-specific columns to activities
-- =====================================================
BEGIN;

-- Check if columns already exist (they should from previous partial run)
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS cycling_power_watts integer,
  ADD COLUMN IF NOT EXISTS cycling_ftp_watts integer,
  ADD COLUMN IF NOT EXISTS cycling_speed_mph real,
  ADD COLUMN IF NOT EXISTS cycling_terrain text,
  ADD COLUMN IF NOT EXISTS cycling_indoor_outdoor text,
  ADD COLUMN IF NOT EXISTS cycling_elevation_gain_ft integer,
  ADD COLUMN IF NOT EXISTS cycling_session_goal text;

-- Add cycling constraint checks (drop first if exists to make idempotent)
ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activities_cycling_terrain_check;
ALTER TABLE public.activities
  ADD CONSTRAINT activities_cycling_terrain_check
  CHECK (cycling_terrain IS NULL OR cycling_terrain = ANY (ARRAY['flat'::text, 'rolling'::text, 'hilly'::text]));

ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activities_cycling_indoor_outdoor_check;
ALTER TABLE public.activities
  ADD CONSTRAINT activities_cycling_indoor_outdoor_check
  CHECK (cycling_indoor_outdoor IS NULL OR cycling_indoor_outdoor = ANY (ARRAY['indoor'::text, 'outdoor'::text]));

ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activities_cycling_session_goal_check;
ALTER TABLE public.activities
  ADD CONSTRAINT activities_cycling_session_goal_check
  CHECK (cycling_session_goal IS NULL OR cycling_session_goal = ANY (ARRAY['endurance'::text, 'tempo'::text, 'intervals'::text]));

-- Add cycling column comments
COMMENT ON COLUMN public.activities.sport_type IS 'Type of endurance sport: running, cycling, or swimming';
COMMENT ON COLUMN public.activities.cycling_power_watts IS 'Average power output in watts for cycling activities';
COMMENT ON COLUMN public.activities.cycling_ftp_watts IS 'Functional Threshold Power in watts (if known)';
COMMENT ON COLUMN public.activities.cycling_speed_mph IS 'Average cycling speed in miles per hour';
COMMENT ON COLUMN public.activities.cycling_terrain IS 'Terrain type: flat, rolling, or hilly';
COMMENT ON COLUMN public.activities.cycling_indoor_outdoor IS 'Indoor (trainer) or outdoor cycling';
COMMENT ON COLUMN public.activities.cycling_elevation_gain_ft IS 'Total elevation gain in feet';
COMMENT ON COLUMN public.activities.cycling_session_goal IS 'Session type: endurance, tempo, or intervals';

COMMIT;

-- =====================================================
-- STEP 5: Add swimming-specific columns to activities
-- =====================================================
BEGIN;

ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS swimming_speed_per_100m integer,
  ADD COLUMN IF NOT EXISTS swimming_css_seconds_per_100m integer,
  ADD COLUMN IF NOT EXISTS swimming_pace_per_100m_seconds integer,
  ADD COLUMN IF NOT EXISTS swimming_pool_or_open_water text,
  ADD COLUMN IF NOT EXISTS swimming_water_temp_c real;

-- Add swimming constraint checks (drop first if exists to make idempotent)
ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activities_swimming_pool_or_open_water_check;
ALTER TABLE public.activities
  ADD CONSTRAINT activities_swimming_pool_or_open_water_check
  CHECK (swimming_pool_or_open_water IS NULL OR swimming_pool_or_open_water = ANY (ARRAY['pool'::text, 'open_water'::text]));

-- Add swimming column comments
COMMENT ON COLUMN public.activities.swimming_speed_per_100m IS 'Average pace in seconds per 100 meters for swimming';
COMMENT ON COLUMN public.activities.swimming_css_seconds_per_100m IS 'Critical Swim Speed in seconds per 100m (if known)';
COMMENT ON COLUMN public.activities.swimming_pace_per_100m_seconds IS 'Swimming pace in seconds per 100 meters';
COMMENT ON COLUMN public.activities.swimming_pool_or_open_water IS 'Pool or open water swimming';
COMMENT ON COLUMN public.activities.swimming_water_temp_c IS 'Water temperature in Celsius';

COMMIT;

-- =====================================================
-- STEP 6: Add cross-sport columns to activities
-- =====================================================
BEGIN;

ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS intensity_target text,
  ADD COLUMN IF NOT EXISTS time_before_minutes integer;

-- Add column comments
COMMENT ON COLUMN public.activities.intensity_target IS 'Intensity target (zone_1, zone_2, rpe_3, etc.) - works across all sports';
COMMENT ON COLUMN public.activities.time_before_minutes IS 'Pre-activity timing window in minutes (replaces run-specific pre_run_timing)';

COMMIT;

-- =====================================================
-- STEP 7: Add validation constraints
-- =====================================================
BEGIN;

-- Constraint: cycling columns only for cycling activities (drop first if exists to make idempotent)
ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activities_cycling_columns_check;
ALTER TABLE public.activities
  ADD CONSTRAINT activities_cycling_columns_check
  CHECK (
    (sport_type = 'cycling' AND cycling_power_watts IS NOT NULL) OR
    (sport_type <> 'cycling' AND cycling_power_watts IS NULL AND cycling_ftp_watts IS NULL)
  );

-- Constraint: swimming columns only for swimming activities (drop first if exists to make idempotent)
ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activities_swimming_columns_check;
ALTER TABLE public.activities
  ADD CONSTRAINT activities_swimming_columns_check
  CHECK (
    (sport_type = 'swimming' AND swimming_speed_per_100m IS NOT NULL) OR
    (sport_type <> 'swimming' AND swimming_speed_per_100m IS NULL AND swimming_css_seconds_per_100m IS NULL)
  );

COMMIT;

-- =====================================================
-- STEP 8: Update activity_type comment
-- =====================================================
COMMENT ON COLUMN public.activities.activity_type IS 'Type of endurance sport: running, cycling, or swimming';

-- =====================================================
-- STEP 9: Create indexes for new columns
-- =====================================================
BEGIN;

-- Indexes for filtering by sport type
CREATE INDEX IF NOT EXISTS idx_activities_sport_type ON public.activities(sport_type);

-- Partial indexes for sport-specific queries
CREATE INDEX IF NOT EXISTS idx_activities_cycling_power
  ON public.activities(cycling_power_watts)
  WHERE cycling_power_watts IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_activities_swimming_pace
  ON public.activities(swimming_speed_per_100m)
  WHERE swimming_speed_per_100m IS NOT NULL;

COMMIT;

-- =====================================================
-- VERIFICATION QUERIES - Run these to confirm success
-- =====================================================

-- Check users table has new columns (should be 4 rows)
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name IN ('cycling_ftp_watts', 'prefers_cycling_power', 'swimming_css_seconds_per_100m', 'prefers_swimming_pace')
ORDER BY column_name;

-- Check activities table has new columns (should be 16 rows)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'activities'
  AND column_name IN (
    'sport_type',
    'cycling_power_watts', 'cycling_ftp_watts', 'cycling_speed_mph', 'cycling_terrain',
    'cycling_indoor_outdoor', 'cycling_elevation_gain_ft', 'cycling_session_goal',
    'swimming_speed_per_100m', 'swimming_css_seconds_per_100m', 'swimming_pace_per_100m_seconds',
    'swimming_pool_or_open_water', 'swimming_water_temp_c',
    'intensity_target', 'time_before_minutes'
  )
ORDER BY column_name;

-- Check constraint existence (should show multiple constraints)
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name = 'activities'
  AND (constraint_name LIKE '%cycling%' OR constraint_name LIKE '%swimming%' OR constraint_name LIKE '%sport_type%')
ORDER BY constraint_name;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
-- If all verification queries return expected results:
-- ✅ Migration completed successfully!
-- ✅ Production schema now matches dev schema
-- ✅ All multi-sport columns and constraints in place
