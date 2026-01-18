-- ============================================================================
-- Migration: Expand category_enum for Multi-Sport Support (PHASE 1 - ADDITIVE ONLY)
--
-- Purpose: Add new category values for sport-specific filtering
-- This is a NON-BREAKING migration - old values still work
--
-- Old enum values (KEPT): before_run, during_run, after_run
-- New enum values (ADDED): before, during_bike, during_swim, after, transition
--
-- NOTE: NO columns are dropped in this migration to maintain backwards compatibility
-- with older app versions. Column cleanup will happen in Phase 2 after forced update.
-- ============================================================================

-- ============================================================================
-- STEP 1: Add new enum values (PostgreSQL allows ADD VALUE, won't remove old ones)
-- ============================================================================

-- Add 'before' value (universal pre-activity - alias for before_run)
DO $$ BEGIN
  ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'before';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Add 'during_bike' value (cycling-specific during phase)
DO $$ BEGIN
  ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'during_bike';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Add 'during_swim' value (swimming-specific during phase)
DO $$ BEGIN
  ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'during_swim';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Add 'after' value (universal post-activity - alias for after_run)
DO $$ BEGIN
  ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'after';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Add 'transition' value (triathlon-specific transition zone)
DO $$ BEGIN
  ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'transition';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- STEP 2: Auto-populate sport-specific during categories for existing foods
-- This adds NEW categories without removing old ones - foods can have multiple
--
-- NOTE: We ADD to the categories array, we don't replace values
-- ============================================================================

-- For cycling: bars, waffles, real_food are suitable during bike
-- These foods already have during_run, we ADD during_bike
UPDATE foods
SET categories = array_append(categories, 'during_bike'::category_enum)
WHERE 'during_run' = ANY(categories)
  AND product_type IN ('bar', 'waffle', 'real_food', 'real_food_carbs', 'solid_carb_snacks')
  AND NOT 'during_bike' = ANY(categories);

-- For swimming: only gels and drinks at aid stations
-- These foods already have during_run, we ADD during_swim
UPDATE foods
SET categories = array_append(categories, 'during_swim'::category_enum)
WHERE 'during_run' = ANY(categories)
  AND product_type IN ('gel', 'drink_mix', 'sports_drink', 'hydration_with_carbs', 'electrolytes_fluids', 'electrolyte_only')
  AND NOT 'during_swim' = ANY(categories);

-- ============================================================================
-- STEP 3: Add new universal categories to foods that have the old values
-- Foods with before_run also get 'before', foods with after_run also get 'after'
-- This enables the edge function to find foods using either old or new values
-- ============================================================================

-- Add 'before' to foods that have 'before_run'
UPDATE foods
SET categories = array_append(categories, 'before'::category_enum)
WHERE 'before_run' = ANY(categories)
  AND NOT 'before' = ANY(categories);

-- Add 'after' to foods that have 'after_run'
UPDATE foods
SET categories = array_append(categories, 'after'::category_enum)
WHERE 'after_run' = ANY(categories)
  AND NOT 'after' = ANY(categories);

-- ============================================================================
-- STEP 4: Add comments documenting the new category system
-- ============================================================================

COMMENT ON COLUMN foods.categories IS 'Multi-sport category phases. Legacy values (before_run, during_run, after_run) still work. New values: before (universal), during_bike (cycling), during_swim (swimming), after (universal), transition (triathlon). Foods can have multiple categories.';

COMMENT ON COLUMN user_foods.categories IS 'Multi-sport category phases. Legacy values (before_run, during_run, after_run) still work. New values: before (universal), during_bike (cycling), during_swim (swimming), after (universal), transition (triathlon). Foods can have multiple categories.';

-- ============================================================================
-- NOTE: The following columns are NOT dropped in this migration:
--
-- foods table (kept for backwards compatibility):
--   - before_run_suitable, during_run_suitable, after_run_suitable
--   - activity_types
--   - is_other_food, nutritional_info, preference_priority
--
-- user_foods table (kept for backwards compatibility):
--   - activity_types
--
-- These will be deprecated and removed in Phase 2 after all users have
-- updated to app versions that use the new category system.
-- ============================================================================

-- ============================================================================
-- Migration complete!
--
-- New category_enum values (all legacy values still work):
--   - before: Universal pre-activity (equivalent to before_run)
--   - during_run: Running during activity (unchanged)
--   - during_bike: Cycling during activity (more solid foods allowed)
--   - during_swim: Swimming during activity (liquids/gels only)
--   - after: Universal post-activity (equivalent to after_run)
--   - transition: Triathlon transition zone nutrition
--
-- Edge function handles BOTH old and new values via getCategoryForPhase()
-- ============================================================================
