-- ============================================================================
-- Migration 006: Convert TIMESTAMPTZ to Naive TIMESTAMP
-- ============================================================================
-- Description: Convert timezone-aware timestamps to naive UTC timestamps
-- Date: 2025-01-07
-- ============================================================================

BEGIN;

-- ============================================================================
-- Helper function to convert TIMESTAMPTZ columns to TIMESTAMP
-- ============================================================================

CREATE OR REPLACE FUNCTION convert_timestamptz_to_timestamp(
  p_table_name TEXT,
  p_column_name TEXT
) RETURNS VOID AS $$
DECLARE
  v_sql TEXT;
BEGIN
  -- Convert column to naive TIMESTAMP (storing UTC)
  v_sql := format(
    'ALTER TABLE %I ALTER COLUMN %I TYPE TIMESTAMP USING %I AT TIME ZONE ''UTC''',
    p_table_name,
    p_column_name,
    p_column_name
  );

  EXECUTE v_sql;

  -- Update default if it exists
  v_sql := format(
    'ALTER TABLE %I ALTER COLUMN %I SET DEFAULT (NOW() AT TIME ZONE ''UTC'')',
    p_table_name,
    p_column_name
  );

  BEGIN
    EXECUTE v_sql;
  EXCEPTION
    WHEN OTHERS THEN
      -- Column might not have a default, that's okay
      NULL;
  END;

  RAISE NOTICE 'Converted %.% from TIMESTAMPTZ to TIMESTAMP', p_table_name, p_column_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Convert all timestamp columns
-- ============================================================================

-- Users table
SELECT convert_timestamptz_to_timestamp('users', 'created_at');
SELECT convert_timestamptz_to_timestamp('users', 'updated_at');
SELECT convert_timestamptz_to_timestamp('users', 'last_active_at');

-- App content table
SELECT convert_timestamptz_to_timestamp('app_content', 'created_at');
SELECT convert_timestamptz_to_timestamp('app_content', 'updated_at');

-- Feedback table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'feedback') THEN
    PERFORM convert_timestamptz_to_timestamp('feedback', 'created_at');
  END IF;
END $$;

-- Macro targets table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'macro_targets') THEN
    PERFORM convert_timestamptz_to_timestamp('macro_targets', 'created_at');
    PERFORM convert_timestamptz_to_timestamp('macro_targets', 'updated_at');
  END IF;
END $$;

-- Food preferences table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'food_preferences') THEN
    PERFORM convert_timestamptz_to_timestamp('food_preferences', 'created_at');
    PERFORM convert_timestamptz_to_timestamp('food_preferences', 'updated_at');
  END IF;
END $$;

-- Weather forecasts table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'weather_forecasts') THEN
    PERFORM convert_timestamptz_to_timestamp('weather_forecasts', 'forecast_time');
    PERFORM convert_timestamptz_to_timestamp('weather_forecasts', 'created_at');
  END IF;
END $$;

-- Activity completions table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'activity_completions') THEN
    PERFORM convert_timestamptz_to_timestamp('activity_completions', 'completed_at');
    PERFORM convert_timestamptz_to_timestamp('activity_completions', 'created_at');
  END IF;
END $$;

-- Carb loading day meals table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'carb_loading_day_meals') THEN
    PERFORM convert_timestamptz_to_timestamp('carb_loading_day_meals', 'created_at');
    PERFORM convert_timestamptz_to_timestamp('carb_loading_day_meals', 'updated_at');
  END IF;
END $$;

-- Edge functions table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'edge_functions') THEN
    PERFORM convert_timestamptz_to_timestamp('edge_functions', 'last_called_at');
  END IF;
END $$;

-- Note: activities, events, carb_loading_plans already use TIMESTAMP (not TIMESTAMPTZ)
-- from migration 003

-- Clean up helper function
DROP FUNCTION convert_timestamptz_to_timestamp(TEXT, TEXT);

COMMIT;

SELECT 'Timestamps converted to naive TIMESTAMP (UTC)' AS status;
