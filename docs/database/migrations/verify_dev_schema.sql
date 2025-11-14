-- =====================================================
-- Schema Verification: Dev Environment
-- =====================================================
-- Purpose: Verify dev schema matches the complete multi-sport schema
-- Date: 2025-11-06
-- Status: VERIFICATION ONLY
--
-- Dev already has most multi-sport columns. This script verifies
-- and adds any missing pieces to ensure 100% parity.
-- =====================================================

-- =====================================================
-- VERIFICATION: Check users table columns
-- =====================================================
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
ORDER BY ordinal_position;

-- Expected columns (38 total including multi-sport):
-- cycling_ftp_watts, prefers_cycling_power, swimming_css_seconds_per_100m, prefers_swimming_pace

-- =====================================================
-- VERIFICATION: Check activities table columns
-- =====================================================
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'activities'
ORDER BY ordinal_position;

-- Expected multi-sport columns:
-- sport_type (default 'running')
-- cycling_power_watts, cycling_ftp_watts, cycling_speed_mph, cycling_terrain,
-- cycling_indoor_outdoor, cycling_elevation_gain_ft, cycling_session_goal
-- swimming_speed_per_100m, swimming_css_seconds_per_100m, swimming_pace_per_100m_seconds,
-- swimming_pool_or_open_water, swimming_water_temp_c
-- intensity_target, time_before_minutes

-- =====================================================
-- VERIFICATION: Check constraints
-- =====================================================
SELECT
  tc.constraint_name,
  tc.constraint_type,
  cc.check_clause
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.check_constraints cc
  ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.table_name = 'activities'
  AND (tc.constraint_name LIKE '%sport%'
    OR tc.constraint_name LIKE '%cycling%'
    OR tc.constraint_name LIKE '%swimming%')
ORDER BY tc.constraint_name;

-- Expected constraints:
-- activities_sport_type_check
-- activities_cycling_columns_check
-- activities_swimming_columns_check
-- activities_cycling_terrain_check
-- activities_cycling_indoor_outdoor_check
-- activities_cycling_session_goal_check
-- activities_swimming_pool_or_open_water_check

-- =====================================================
-- If dev is missing anything, apply minimal fixes:
-- =====================================================

-- Only uncomment if verification shows missing columns/constraints

-- BEGIN;
--
-- -- Example: Add missing indexes
-- CREATE INDEX IF NOT EXISTS idx_activities_sport_type ON public.activities(sport_type);
-- CREATE INDEX IF NOT EXISTS idx_activities_cycling_power
--   ON public.activities(cycling_power_watts)
--   WHERE cycling_power_watts IS NOT NULL;
-- CREATE INDEX IF NOT EXISTS idx_activities_swimming_pace
--   ON public.activities(swimming_speed_per_100m)
--   WHERE swimming_speed_per_100m IS NOT NULL;
--
-- COMMIT;

-- =====================================================
-- RESULT SUMMARY
-- =====================================================
-- Dev environment should already have complete schema.
-- If any discrepancies found above, apply minimal fixes.
-- Then regenerate Drift schema snapshot:
--   dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/
