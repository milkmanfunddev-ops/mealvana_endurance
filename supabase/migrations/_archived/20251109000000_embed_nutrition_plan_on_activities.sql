-- Migration: Embed Nutrition Plans on Activities
-- Date: 2025-11-09
-- Description: Adds nutrition plan metadata directly to activities and removes the standalone nutrition_plans table.

BEGIN;

-- 1. Ensure activities owns the nutrition plan JSON
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS nutrition_plan_data JSONB;

COMMENT ON COLUMN public.activities.nutrition_plan_data IS 'Full JSON payload for the nutrition plan (before/during/after sections, macro targets, notes)';

-- Drop the deprecated nutrition_plan_id column if it still exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'activities'
      AND column_name = 'nutrition_plan_id'
  ) THEN
    ALTER TABLE public.activities
      DROP COLUMN nutrition_plan_id;
  END IF;
END $$;

-- 2. Backfill plan data from legacy nutrition_plans table if it still exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'nutrition_plans'
  ) THEN
    PERFORM 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'nutrition_plans'
        AND column_name = 'activity_id';

    -- Only attempt the backfill if activity_id exists on the legacy table
    IF FOUND THEN
      RAISE NOTICE 'Backfilling nutrition plans onto activities';
      UPDATE public.activities a
         SET nutrition_plan_data = COALESCE(a.nutrition_plan_data, np.plan_data)
        FROM public.nutrition_plans np
       WHERE np.activity_id = a.id
         AND np.plan_data IS NOT NULL
         AND a.nutrition_plan_data IS NULL;
    END IF;
  END IF;
END $$;

-- 3. Drop the legacy nutrition_plans table
DROP TABLE IF EXISTS public.nutrition_plans CASCADE;

COMMIT;
