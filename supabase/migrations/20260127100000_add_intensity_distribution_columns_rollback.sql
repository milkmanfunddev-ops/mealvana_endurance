-- ============================================================================
-- Rollback Migration: Remove Intensity Distribution Columns
--
-- Purpose: Rollback changes from 20260127100000_add_intensity_distribution_columns.sql
--
-- Changes:
--   1. Drop intensity_z1_z2_pct from activities table
--   2. Drop intensity_z3_z4_pct from activities table
--   3. Drop intensity_z5_pct from activities table
--   4. Drop default_running_pace_min_per_mile from users table
--   5. Drop default_cycling_speed_mph from users table
--   6. Drop default_swimming_pace_per_100_sec from users table
--
-- WARNING: This will permanently delete all intensity distribution data
--          and user default pace/speed settings!
-- ============================================================================

-- ============================================================================
-- STEP 1: Drop intensity distribution columns from activities table
-- ============================================================================

ALTER TABLE activities
DROP COLUMN IF EXISTS intensity_z1_z2_pct;

ALTER TABLE activities
DROP COLUMN IF EXISTS intensity_z3_z4_pct;

ALTER TABLE activities
DROP COLUMN IF EXISTS intensity_z5_pct;

-- ============================================================================
-- STEP 2: Drop default pace/speed columns from users table
-- ============================================================================

ALTER TABLE users
DROP COLUMN IF EXISTS default_running_pace_min_per_mile;

ALTER TABLE users
DROP COLUMN IF EXISTS default_cycling_speed_mph;

ALTER TABLE users
DROP COLUMN IF EXISTS default_swimming_pace_per_100_sec;

-- ============================================================================
-- Rollback complete!
--
-- Removed columns from activities table:
--   - intensity_z1_z2_pct
--   - intensity_z3_z4_pct
--   - intensity_z5_pct
--
-- Removed columns from users table:
--   - default_running_pace_min_per_mile
--   - default_cycling_speed_mph
--   - default_swimming_pace_per_100_sec
--
-- Note: All intensity distribution data and user pace/speed settings
--       have been permanently deleted. If you need to restore this data,
--       you must recover from a database backup taken before rollback.
-- ============================================================================
