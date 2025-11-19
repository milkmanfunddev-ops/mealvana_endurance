-- Migration: Add index to foods table for show_in_preferences query performance
-- Created: 2025-01-19
-- Issue: Additional foods query timing out (10+ seconds)
-- Root Cause: Missing index on show_in_preferences column
-- Expected Impact: Query time reduces from 10+ seconds to ~50-170ms

-- Create composite index for show_in_preferences + name
-- This supports both the WHERE clause and ORDER BY clause in a single index
CREATE INDEX IF NOT EXISTS idx_foods_show_in_preferences_name
ON public.foods (show_in_preferences, name ASC);

-- Verify index was created
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'foods'
  AND indexname = 'idx_foods_show_in_preferences_name';

-- Expected output after migration:
-- This query should now use Index Scan instead of Seq Scan
-- EXPLAIN ANALYZE
-- SELECT id, name, display_name, display_name_plural, image_address,
--        serving_amount, max_servings_before, max_servings_during, max_servings_after,
--        carbs_per_serving, protein_per_serving, fat_per_serving, calories_per_serving,
--        fluid_ml_per_serving, sodium_mg, caffeine_mg, potassium_mg,
--        product_type, show_in_preferences, is_electrolyte, to_exclude_from_solver,
--        created_at
-- FROM foods
-- WHERE show_in_preferences = false
-- ORDER BY name ASC;
