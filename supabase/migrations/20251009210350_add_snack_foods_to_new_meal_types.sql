-- ============================================================================
-- Add Snack Foods to New Specific Meal Types
-- ============================================================================
-- This migration adds food associations for the three new specific snack types:
-- - Morning Snack (meal_type_id = 5)
-- - Afternoon Snack (meal_type_id = 6)
-- - Evening Snack (meal_type_id = 7)
--
-- These new meal types were added to replace the deprecated general "Snacks"
-- (meal_type_id = 4), but the original seed migration only included associations
-- for meal types 1-4.
-- ============================================================================

-- Morning Snack Foods (meal_type_id = 5) - same as general snacks
INSERT INTO carb_loading_food_meal_types (carb_loading_food_id, meal_type_id)
SELECT id, 5 FROM carb_loading_foods WHERE name IN (
  'dates', 'berries', 'apple', 'pretzels', 'graham_crackers', 'saltines',
  'fig_bar', 'sports_drink', 'energy_gel', 'rice_pudding', 'beet_juice', 'banana'
)
ON CONFLICT DO NOTHING;

-- Afternoon Snack Foods (meal_type_id = 6) - same as general snacks
INSERT INTO carb_loading_food_meal_types (carb_loading_food_id, meal_type_id)
SELECT id, 6 FROM carb_loading_foods WHERE name IN (
  'dates', 'berries', 'apple', 'pretzels', 'graham_crackers', 'saltines',
  'fig_bar', 'sports_drink', 'energy_gel', 'rice_pudding', 'beet_juice', 'banana'
)
ON CONFLICT DO NOTHING;

-- Evening Snack Foods (meal_type_id = 7) - same as general snacks
INSERT INTO carb_loading_food_meal_types (carb_loading_food_id, meal_type_id)
SELECT id, 7 FROM carb_loading_foods WHERE name IN (
  'dates', 'berries', 'apple', 'pretzels', 'graham_crackers', 'saltines',
  'fig_bar', 'sports_drink', 'energy_gel', 'rice_pudding', 'beet_juice', 'banana'
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
  morning_snack_count INTEGER;
  afternoon_snack_count INTEGER;
  evening_snack_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO morning_snack_count
  FROM carb_loading_food_meal_types
  WHERE meal_type_id = 5;

  SELECT COUNT(*) INTO afternoon_snack_count
  FROM carb_loading_food_meal_types
  WHERE meal_type_id = 6;

  SELECT COUNT(*) INTO evening_snack_count
  FROM carb_loading_food_meal_types
  WHERE meal_type_id = 7;

  RAISE NOTICE 'Migration completed successfully';
  RAISE NOTICE 'Morning Snack foods: %', morning_snack_count;
  RAISE NOTICE 'Afternoon Snack foods: %', afternoon_snack_count;
  RAISE NOTICE 'Evening Snack foods: %', evening_snack_count;

  IF morning_snack_count < 12 OR afternoon_snack_count < 12 OR evening_snack_count < 12 THEN
    RAISE WARNING 'Expected 12 foods for each new snack type';
  END IF;
END $$;
