-- ============================================================================
-- Migration 004: Add Array-Based Categories to Foods
-- ============================================================================
-- Description: Replace join tables with PostgreSQL arrays
-- Date: 2025-01-07
-- ============================================================================

BEGIN;

-- ============================================================================
-- Add array columns to foods table
-- ============================================================================

ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS categories category_enum[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS activity_types sport_enum[] DEFAULT '{}';

-- Add indexes for array containment queries
CREATE INDEX IF NOT EXISTS idx_foods_categories_gin ON public.foods USING GIN (categories);
CREATE INDEX IF NOT EXISTS idx_foods_activity_types_gin ON public.foods USING GIN (activity_types);

-- Add comments
COMMENT ON COLUMN public.foods.categories IS 'Array of food categories (before_run, during_run, after_run)';
COMMENT ON COLUMN public.foods.activity_types IS 'Array of suitable activity types (running, cycling, swimming)';

-- ============================================================================
-- Add array columns to user_foods table
-- ============================================================================

ALTER TABLE public.user_foods
  ADD COLUMN IF NOT EXISTS categories category_enum[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS activity_types sport_enum[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_user_foods_categories_gin ON public.user_foods USING GIN (categories);
CREATE INDEX IF NOT EXISTS idx_user_foods_activity_types_gin ON public.user_foods USING GIN (activity_types);

COMMENT ON COLUMN public.user_foods.categories IS 'Array of food categories (before_run, during_run, after_run)';
COMMENT ON COLUMN public.user_foods.activity_types IS 'Array of suitable activity types (running, cycling, swimming)';

-- ============================================================================
-- Add array columns to carb_loading_foods table
-- ============================================================================

ALTER TABLE public.carb_loading_foods
  ADD COLUMN IF NOT EXISTS meal_types TEXT[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_carb_loading_foods_meal_types_gin ON public.carb_loading_foods USING GIN (meal_types);

COMMENT ON COLUMN public.carb_loading_foods.meal_types IS 'Array of meal types (breakfast, lunch, dinner, snack)';

-- ============================================================================
-- Add array columns to carb_loading_user_foods table
-- ============================================================================

ALTER TABLE public.carb_loading_user_foods
  ADD COLUMN IF NOT EXISTS meal_types TEXT[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_meal_types_gin ON public.carb_loading_user_foods USING GIN (meal_types);

COMMENT ON COLUMN public.carb_loading_user_foods.meal_types IS 'Array of meal types (breakfast, lunch, dinner, snack)';

COMMIT;

SELECT 'Array-based categories added to foods tables' AS status;
