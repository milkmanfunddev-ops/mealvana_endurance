-- =====================================================
-- Schema Sync Migration: Production → Dev Parity
-- =====================================================
-- Purpose: Add missing multi-sport columns to production Supabase
-- Date: 2025-11-06
-- Status: PENDING - DO NOT RUN WITHOUT BACKUP
--
-- Impact: Adds multi-sport support columns to users and activities tables
-- Downtime: None (all columns nullable or have defaults)
-- Rollback: See rollback script below
-- =====================================================

-- =====================================================
-- STEP 1: Backup existing data (REQUIRED)
-- =====================================================
-- Run these commands BEFORE applying migration:
--
-- pg_dump -h <prod-host> -U postgres -d postgres -t users -t activities > backup_before_sync_$(date +%Y%m%d).sql
--

-- =====================================================
-- STEP 2: Add missing columns to users table
-- =====================================================
BEGIN;

-- Add cycling preference columns
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS cycling_ftp_watts integer,
  ADD COLUMN IF NOT EXISTS prefers_cycling_power boolean DEFAULT false;

-- Add swimming preference columns
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS swimming_css_seconds_per_100m integer,
  ADD COLUMN IF NOT EXISTS prefers_swimming_pace boolean DEFAULT false;

-- Add column comments
COMMENT ON COLUMN public.users.cycling_ftp_watts IS 'User default FTP (Functional Threshold Power) in watts';
COMMENT ON COLUMN public.users.prefers_cycling_power IS 'Whether user prefers to input power vs speed for cycling';
COMMENT ON COLUMN public.users.swimming_css_seconds_per_100m IS 'User default CSS (Critical Swim Speed) in seconds per 100m';
COMMENT ON COLUMN public.users.prefers_swimming_pace IS 'Whether user prefers to input pace vs speed for swimming';

COMMIT;

-- =====================================================
-- STEP 3: Update activities table
-- =====================================================
BEGIN;

-- First, drop the old activity_type constraint (running/event)
ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activity_type_check;

-- Add new activity_type constraint (running/cycling/swimming)
ALTER TABLE public.activities
  ADD CONSTRAINT activity_type_check
  CHECK (activity_type = ANY (ARRAY['running'::text, 'cycling'::text, 'swimming'::text]));

-- Add sport_type column with default
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS sport_type text DEFAULT 'running'::text;

-- Add sport_type constraint
ALTER TABLE public.activities
  ADD CONSTRAINT activities_sport_type_check
  CHECK (sport_type = ANY (ARRAY['running'::text, 'cycling'::text, 'swimming'::text]));

COMMIT;

-- =====================================================
-- STEP 4: Add cycling-specific columns to activities
-- =====================================================
BEGIN;

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
-- VERIFICATION QUERIES
-- =====================================================
-- Run these after migration to verify success:
--
-- -- Check users table has new columns
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name = 'users'
--   AND column_name IN ('cycling_ftp_watts', 'prefers_cycling_power', 'swimming_css_seconds_per_100m', 'prefers_swimming_pace')
-- ORDER BY column_name;
--
-- -- Check activities table has new columns
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name = 'activities'
--   AND column_name IN ('sport_type', 'cycling_power_watts', 'cycling_ftp_watts', 'swimming_speed_per_100m', 'swimming_css_seconds_per_100m', 'intensity_target', 'time_before_minutes')
-- ORDER BY column_name;
--
-- -- Check constraint existence
-- SELECT constraint_name, constraint_type
-- FROM information_schema.table_constraints
-- WHERE table_schema = 'public'
--   AND table_name = 'activities'
--   AND constraint_name LIKE '%cycling%' OR constraint_name LIKE '%swimming%' OR constraint_name LIKE '%sport_type%'
-- ORDER BY constraint_name;

-- =====================================================
-- ROLLBACK SCRIPT (use if migration fails)
-- =====================================================
-- BEGIN;
--
-- -- Remove users columns
-- ALTER TABLE public.users
--   DROP COLUMN IF EXISTS cycling_ftp_watts,
--   DROP COLUMN IF EXISTS prefers_cycling_power,
--   DROP COLUMN IF EXISTS swimming_css_seconds_per_100m,
--   DROP COLUMN IF EXISTS prefers_swimming_pace;
--
-- -- Remove activities columns
-- ALTER TABLE public.activities
--   DROP COLUMN IF EXISTS sport_type,
--   DROP COLUMN IF EXISTS cycling_power_watts,
--   DROP COLUMN IF EXISTS cycling_ftp_watts,
--   DROP COLUMN IF EXISTS cycling_speed_mph,
--   DROP COLUMN IF EXISTS cycling_terrain,
--   DROP COLUMN IF EXISTS cycling_indoor_outdoor,
--   DROP COLUMN IF EXISTS cycling_elevation_gain_ft,
--   DROP COLUMN IF EXISTS cycling_session_goal,
--   DROP COLUMN IF EXISTS swimming_speed_per_100m,
--   DROP COLUMN IF EXISTS swimming_css_seconds_per_100m,
--   DROP COLUMN IF EXISTS swimming_pace_per_100m_seconds,
--   DROP COLUMN IF EXISTS swimming_pool_or_open_water,
--   DROP COLUMN IF EXISTS swimming_water_temp_c,
--   DROP COLUMN IF EXISTS intensity_target,
--   DROP COLUMN IF EXISTS time_before_minutes;
--
-- -- Restore old activity_type constraint
-- ALTER TABLE public.activities
--   DROP CONSTRAINT IF EXISTS activity_type_check;
-- ALTER TABLE public.activities
--   ADD CONSTRAINT activity_type_check
--   CHECK (activity_type = ANY (ARRAY['running'::text, 'event'::text]));
--
-- -- Drop indexes
-- DROP INDEX IF EXISTS idx_activities_sport_type;
-- DROP INDEX IF EXISTS idx_activities_cycling_power;
-- DROP INDEX IF EXISTS idx_activities_swimming_pace;
--
-- COMMIT;
