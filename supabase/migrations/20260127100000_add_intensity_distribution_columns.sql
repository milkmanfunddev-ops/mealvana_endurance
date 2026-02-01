-- ============================================================================
-- Migration: Add Intensity Distribution Columns
--
-- Purpose: Support three-zone intensity distribution tracking for all
--          activity types (running, cycling, swimming, brick)
--
-- Changes:
--   1. Add intensity_z1_z2_pct (INTEGER) to activities table
--   2. Add intensity_z3_z4_pct (INTEGER) to activities table
--   3. Add intensity_z5_pct (INTEGER) to activities table
--   4. Add default_running_pace_min_per_mile (REAL) to users table
--   5. Add default_cycling_speed_mph (REAL) to users table
--   6. Add default_swimming_pace_per_100_sec (INTEGER) to users table
--
-- Intensity Zones:
--   - Z1-Z2 (Conversational): Easy effort, can hold conversation
--   - Z3-Z4 (Tempo): Moderate-hard effort
--   - Z5+ (All-Out): Maximum effort, race pace
--
-- Default Pace/Speed Fields:
--   Used to estimate workout duration from distance in new activity input forms.
--   User can override these defaults when creating activities.
--
-- UI Implementation:
--   - IntensityDistributionWidget: Composite bar + three zone sliders
--   - WorkoutDetailsWidget: Distance input with "By Duration" / "By Pace" toggle
--   - Default values: 70% Z1-Z2, 20% Z3-Z4, 10% Z5+
--
-- Feature: /docs/new_intensity/README.md
-- ============================================================================

-- ============================================================================
-- STEP 1: Add intensity distribution columns to activities table
-- All three zones must sum to 100% when present
-- ============================================================================

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS intensity_z1_z2_pct INTEGER DEFAULT NULL;

COMMENT ON COLUMN activities.intensity_z1_z2_pct IS 'Percentage of workout in Conversational zone (Z1-Z2). Range: 0-100. Must sum to 100 with other intensity columns when present. Used for detailed workout intensity tracking.';

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS intensity_z3_z4_pct INTEGER DEFAULT NULL;

COMMENT ON COLUMN activities.intensity_z3_z4_pct IS 'Percentage of workout in Tempo zone (Z3-Z4). Range: 0-100. Must sum to 100 with other intensity columns when present. Used for detailed workout intensity tracking.';

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS intensity_z5_pct INTEGER DEFAULT NULL;

COMMENT ON COLUMN activities.intensity_z5_pct IS 'Percentage of workout in All-Out zone (Z5+). Range: 0-100. Must sum to 100 with other intensity columns when present. Used for detailed workout intensity tracking.';

-- ============================================================================
-- STEP 2: Add default pace/speed columns to users table
-- Used for duration estimation in new activity forms
-- ============================================================================

ALTER TABLE users
ADD COLUMN IF NOT EXISTS default_running_pace_min_per_mile REAL DEFAULT NULL;

COMMENT ON COLUMN users.default_running_pace_min_per_mile IS 'User default running pace in minutes per mile. Used to estimate workout duration from distance in new activity forms. Example: 8.5 = 8:30 min/mile pace.';

ALTER TABLE users
ADD COLUMN IF NOT EXISTS default_cycling_speed_mph REAL DEFAULT NULL;

COMMENT ON COLUMN users.default_cycling_speed_mph IS 'User default cycling speed in miles per hour. Used to estimate workout duration from distance in new activity forms. Example: 18.5 mph.';

ALTER TABLE users
ADD COLUMN IF NOT EXISTS default_swimming_pace_per_100_sec INTEGER DEFAULT NULL;

COMMENT ON COLUMN users.default_swimming_pace_per_100_sec IS 'User default swimming pace in seconds per 100 yards/meters. Used to estimate workout duration from distance in new activity forms. Example: 90 = 1:30 per 100 yards.';

-- ============================================================================
-- Migration complete!
--
-- New columns in activities table:
--   - intensity_z1_z2_pct (INTEGER): Conversational zone percentage (0-100)
--   - intensity_z3_z4_pct (INTEGER): Tempo zone percentage (0-100)
--   - intensity_z5_pct (INTEGER): All-Out zone percentage (0-100)
--
-- New columns in users table:
--   - default_running_pace_min_per_mile (REAL): Default running pace
--   - default_cycling_speed_mph (REAL): Default cycling speed
--   - default_swimming_pace_per_100_sec (INTEGER): Default swimming pace
--
-- Usage in app:
--   1. User sets default paces in profile/onboarding
--   2. New activity form estimates duration from distance using defaults
--   3. User can adjust intensity distribution with three-zone slider widget
--   4. Intensity percentages saved when generating nutrition plan
--   5. For existing activities, intensity columns are NULL (not specified)
--
-- UI Components:
--   - IntensityDistributionWidget: lib/shared/widgets/kyle_design/inputs/
--   - IntensityCompositeBar: Horizontal bar with colored segments
--   - IntensityZoneSlider: Individual zone slider with editable percentage
--   - DurationPaceToggle: "By Duration" / "By Pace" toggle button
--
-- Domain Model:
--   - IntensityDistribution: lib/features/nutrition_plan/domain/
--   - Proportional adjustment algorithm for slider interactions
--   - Validation ensures sum = 100% when all zones present
-- ============================================================================
