-- ============================================================================
-- Mealvana Endurance v2: UUID Migration & Cascade Deletes
-- ============================================================================
-- This migration ensures:
-- 1. All carb loading tables use TEXT (UUID) for IDs (already correct in Supabase)
-- 2. Feature survey responses uses TEXT for ID and device_id (already correct)
-- 3. Cascade deletes work properly for event deletion
-- ============================================================================

-- First, let's verify the current schema is correct (all IDs are TEXT)
-- If any of these queries fail, the schema needs manual intervention

DO $$
BEGIN
  -- Verify carb_loading_plans.id is TEXT
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'carb_loading_plans' 
    AND column_name = 'id' 
    AND data_type = 'text'
  ) THEN
    RAISE EXCEPTION 'carb_loading_plans.id is not TEXT - manual migration required';
  END IF;

  -- Verify carb_loading_days.id is TEXT
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'carb_loading_days' 
    AND column_name = 'id' 
    AND data_type = 'text'
  ) THEN
    RAISE EXCEPTION 'carb_loading_days.id is not TEXT - manual migration required';
  END IF;

  -- Verify carb_loading_day_meals.id is TEXT
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'carb_loading_day_meals' 
    AND column_name = 'id' 
    AND data_type = 'text'
  ) THEN
    RAISE EXCEPTION 'carb_loading_day_meals.id is not TEXT - manual migration required';
  END IF;

  -- Verify feature_survey_responses.id is TEXT
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'feature_survey_responses' 
    AND column_name = 'id' 
    AND data_type = 'text'
  ) THEN
    RAISE EXCEPTION 'feature_survey_responses.id is not TEXT - manual migration required';
  END IF;

  RAISE NOTICE 'All IDs are correctly using TEXT type';
END $$;

-- ============================================================================
-- CASCADE DELETE FIXES
-- ============================================================================

-- DROP and RECREATE foreign key constraints with proper CASCADE behavior

-- 1. carb_loading_plans.event_id → events.id (CASCADE)
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'carb_loading_plans' 
    AND constraint_type = 'FOREIGN KEY'
    AND constraint_name LIKE '%event%'
  ) THEN
    EXECUTE 'ALTER TABLE carb_loading_plans DROP CONSTRAINT carb_loading_plans_event_id_fkey';
    RAISE NOTICE 'Dropped existing carb_loading_plans event FK';
  END IF;
END $$;

ALTER TABLE carb_loading_plans
  ADD CONSTRAINT carb_loading_plans_event_id_fkey 
  FOREIGN KEY (event_id) 
  REFERENCES events(id) 
  ON DELETE CASCADE;

COMMENT ON CONSTRAINT carb_loading_plans_event_id_fkey ON carb_loading_plans IS 
  'When an event is deleted, cascade delete all associated carb loading plans';

-- 2. carb_loading_days.carb_loading_plan_id → carb_loading_plans.id (CASCADE)
-- This should already exist, but let's ensure it's correct
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'carb_loading_days' 
    AND constraint_type = 'FOREIGN KEY'
    AND constraint_name LIKE '%plan%'
  ) THEN
    EXECUTE 'ALTER TABLE carb_loading_days DROP CONSTRAINT carb_loading_days_carb_loading_plan_id_fkey';
    RAISE NOTICE 'Dropped existing carb_loading_days plan FK';
  END IF;
END $$;

ALTER TABLE carb_loading_days
  ADD CONSTRAINT carb_loading_days_carb_loading_plan_id_fkey 
  FOREIGN KEY (carb_loading_plan_id) 
  REFERENCES carb_loading_plans(id) 
  ON DELETE CASCADE;

COMMENT ON CONSTRAINT carb_loading_days_carb_loading_plan_id_fkey ON carb_loading_days IS 
  'When a carb loading plan is deleted, cascade delete all associated days';

-- 3. carb_loading_day_meals.carb_loading_day_id → carb_loading_days.id (CASCADE)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'carb_loading_day_meals' 
    AND constraint_type = 'FOREIGN KEY'
    AND constraint_name LIKE '%day%'
  ) THEN
    EXECUTE 'ALTER TABLE carb_loading_day_meals DROP CONSTRAINT carb_loading_day_meals_carb_loading_day_id_fkey';
    RAISE NOTICE 'Dropped existing carb_loading_day_meals day FK';
  END IF;
END $$;

ALTER TABLE carb_loading_day_meals
  ADD CONSTRAINT carb_loading_day_meals_carb_loading_day_id_fkey 
  FOREIGN KEY (carb_loading_day_id) 
  REFERENCES carb_loading_days(id) 
  ON DELETE CASCADE;

COMMENT ON CONSTRAINT carb_loading_day_meals_carb_loading_day_id_fkey ON carb_loading_day_meals IS 
  'When a carb loading day is deleted, cascade delete all associated meals';

-- 4. activities.event_id → events.id (CASCADE)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'activities' 
    AND constraint_type = 'FOREIGN KEY'
    AND constraint_name LIKE '%event%'
  ) THEN
    EXECUTE 'ALTER TABLE activities DROP CONSTRAINT activities_event_id_fkey';
    RAISE NOTICE 'Dropped existing activities event FK';
  END IF;
END $$;

ALTER TABLE activities
  ADD CONSTRAINT activities_event_id_fkey 
  FOREIGN KEY (event_id) 
  REFERENCES events(id) 
  ON DELETE CASCADE;

COMMENT ON CONSTRAINT activities_event_id_fkey ON activities IS 
  'When an event is deleted, cascade delete all associated activities (but activities can exist without events)';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify cascade chain
DO $$
DECLARE
  cascade_count int;
BEGIN
  SELECT COUNT(*) INTO cascade_count
  FROM information_schema.referential_constraints
  WHERE delete_rule = 'CASCADE'
    AND constraint_name IN (
      'carb_loading_plans_event_id_fkey',
      'carb_loading_days_carb_loading_plan_id_fkey',
      'carb_loading_day_meals_carb_loading_day_id_fkey',
      'activities_event_id_fkey'
    );

  IF cascade_count = 4 THEN
    RAISE NOTICE 'SUCCESS: All 4 cascade delete constraints are in place';
  ELSE
    RAISE WARNING 'Only % of 4 cascade constraints found', cascade_count;
  END IF;
END $$;
