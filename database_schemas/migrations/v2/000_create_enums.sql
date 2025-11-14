-- ============================================================================
-- Migration 000: Create Enums
-- ============================================================================
-- Description: Create all PostgreSQL enums for type safety
-- Date: 2025-01-07
-- ============================================================================

BEGIN;

-- Users
DO $$ BEGIN
  CREATE TYPE gender_enum AS ENUM ('male', 'female', 'other', 'unknown');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Units
DO $$ BEGIN
  CREATE TYPE distance_unit_enum AS ENUM ('miles', 'kilometers');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE pace_unit_enum AS ENUM ('min_per_mile', 'min_per_km');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Gut training
DO $$ BEGIN
  CREATE TYPE gut_training_enum AS ENUM ('low', 'moderate', 'high');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Sports / activities
DO $$ BEGIN
  CREATE TYPE sport_enum AS ENUM ('running', 'cycling', 'swimming');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE activity_status_enum AS ENUM ('planned', 'in_progress', 'completed', 'skipped');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE intensity_enum AS ENUM ('easy', 'moderate', 'hard', 'race');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Cycling terrain
DO $$ BEGIN
  CREATE TYPE cycling_terrain_enum AS ENUM ('flat', 'rolling', 'hilly');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE cycling_indoor_outdoor_enum AS ENUM ('indoor', 'outdoor');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE cycling_session_goal_enum AS ENUM ('endurance', 'intervals', 'tempo', 'recovery');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Swimming
DO $$ BEGIN
  CREATE TYPE swimming_pool_open_water_enum AS ENUM ('pool', 'open_water');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Food categories
DO $$ BEGIN
  CREATE TYPE category_enum AS ENUM ('before_run', 'during_run', 'after_run');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMIT;

-- Verification
SELECT 'Enums created successfully' AS status;
