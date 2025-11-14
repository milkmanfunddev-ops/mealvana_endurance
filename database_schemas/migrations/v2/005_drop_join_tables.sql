-- ============================================================================
-- Migration 005: Drop Join Tables
-- ============================================================================
-- Description: Remove join tables now that we use arrays
-- Date: 2025-01-07
-- ============================================================================

BEGIN;

-- Drop food-related join tables
DROP TABLE IF EXISTS public.food_categories CASCADE;
DROP TABLE IF EXISTS public.user_food_categories CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;

-- Drop carb loading join tables
DROP TABLE IF EXISTS public.carb_loading_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.carb_loading_user_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.meal_types CASCADE;

-- Log the cleanup
SELECT 'Join tables dropped successfully' AS status;

COMMIT;
