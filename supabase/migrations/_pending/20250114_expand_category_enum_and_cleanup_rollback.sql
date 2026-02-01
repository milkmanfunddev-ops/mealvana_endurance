-- ============================================================================
-- ROLLBACK: Expand category_enum for Multi-Sport Support (PHASE 1)
--
-- WARNING: PostgreSQL doesn't allow removing values from enums.
-- This rollback only removes the auto-populated categories from foods.
-- The enum values will remain but won't be used.
-- ============================================================================

-- ============================================================================
-- STEP 1: Remove auto-populated sport-specific categories from foods
-- ============================================================================

-- Remove 'during_bike' from foods
UPDATE foods
SET categories = array_remove(categories, 'during_bike'::category_enum)
WHERE 'during_bike' = ANY(categories);

-- Remove 'during_swim' from foods
UPDATE foods
SET categories = array_remove(categories, 'during_swim'::category_enum)
WHERE 'during_swim' = ANY(categories);

-- Remove 'before' from foods (they'll still have before_run)
UPDATE foods
SET categories = array_remove(categories, 'before'::category_enum)
WHERE 'before' = ANY(categories);

-- Remove 'after' from foods (they'll still have after_run)
UPDATE foods
SET categories = array_remove(categories, 'after'::category_enum)
WHERE 'after' = ANY(categories);

-- Remove 'transition' from foods
UPDATE foods
SET categories = array_remove(categories, 'transition'::category_enum)
WHERE 'transition' = ANY(categories);

-- ============================================================================
-- STEP 2: Restore column comments
-- ============================================================================

COMMENT ON COLUMN foods.categories IS 'Category phases: before_run, during_run, after_run. Foods can have multiple categories.';

COMMENT ON COLUMN user_foods.categories IS 'Category phases: before_run, during_run, after_run. Foods can have multiple categories.';

-- ============================================================================
-- Note: The new enum values (before, during_bike, during_swim, after, transition)
-- cannot be removed from the enum type without dropping and recreating it.
-- They will remain in the enum but won't be used after this rollback.
-- ============================================================================
