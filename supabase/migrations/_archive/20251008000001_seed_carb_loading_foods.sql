-- Migration: Seed Default Carb Loading Foods
-- Description: Populates carb_loading_foods and carb_loading_food_meal_types with default foods
-- Date: 2025-10-08
-- Schema Version: v1

-- ============================================================================
-- Seed Data: carb_loading_foods (Breakfast Foods)
-- ============================================================================

INSERT INTO carb_loading_foods (id, name, display_name, display_name_plural, carbs_per_serving, is_default) VALUES
  (gen_random_uuid(), 'cereal', 'Cereal (1/2 cup dry)', 'Cereal (1/2 cup dry)', 14.0, true),
  (gen_random_uuid(), 'oats', 'Oats (1/2 cup cooked)', 'Oats (1/2 cup cooked)', 14.0, true),
  (gen_random_uuid(), 'banana', 'Banana (1 medium)', 'Bananas (1 medium)', 27.0, true),
  (gen_random_uuid(), 'bagel', 'Bagel (1 large)', 'Bagels (1 large)', 72.0, true),
  (gen_random_uuid(), 'toast', 'Toast (1 slice)', 'Toast (1 slice)', 13.0, true),
  (gen_random_uuid(), 'pancake', 'Pancake (1 medium)', 'Pancakes (1 medium)', 18.0, true),
  (gen_random_uuid(), 'waffle', 'Waffle (1 medium)', 'Waffles (1 medium)', 32.0, true),
  (gen_random_uuid(), 'orange_juice', 'Orange juice (1 cup)', 'Orange juice (1 cup)', 27.0, true),
  (gen_random_uuid(), 'smoothie', 'Smoothie (1 cup)', 'Smoothies (1 cup)', 26.0, true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Seed Data: carb_loading_foods (Lunch & Dinner Foods)
-- ============================================================================

INSERT INTO carb_loading_foods (id, name, display_name, display_name_plural, carbs_per_serving, is_default) VALUES
  (gen_random_uuid(), 'pasta_marinara', 'Pasta with marinara (1 heaping cup cooked)', 'Pasta with marinara (1 heaping cup cooked)', 62.0, true),
  (gen_random_uuid(), 'rice', 'Rice (1 cup cooked)', 'Rice (1 cup cooked)', 45.0, true),
  (gen_random_uuid(), 'baked_potato', 'Baked potato (1 large)', 'Baked potatoes (1 large)', 63.0, true),
  (gen_random_uuid(), 'sweet_potato', 'Sweet potato (1 medium)', 'Sweet potatoes (1 medium)', 25.0, true),
  (gen_random_uuid(), 'beets', 'Beets (1 medium)', 'Beets (1 medium)', 8.0, true),
  (gen_random_uuid(), 'pizza', 'Pizza (1 slice)', 'Pizza (1 slice)', 33.0, true),
  (gen_random_uuid(), 'sandwich', 'Sandwich (1 medium)', 'Sandwiches (1 medium)', 30.0, true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Seed Data: carb_loading_foods (Snack Foods)
-- ============================================================================

INSERT INTO carb_loading_foods (id, name, display_name, display_name_plural, carbs_per_serving, is_default) VALUES
  (gen_random_uuid(), 'dates', 'Dates (1 pair)', 'Dates (1 pair)', 11.0, true),
  (gen_random_uuid(), 'berries', 'Berries (1 cup)', 'Berries (1 cup)', 22.0, true),
  (gen_random_uuid(), 'apple', 'Apple (1 medium)', 'Apples (1 medium)', 25.0, true),
  (gen_random_uuid(), 'pretzels', 'Pretzels (1 oz)', 'Pretzels (1 oz)', 23.0, true),
  (gen_random_uuid(), 'graham_crackers', 'Graham crackers (2 sheets)', 'Graham crackers (2 sheets)', 23.0, true),
  (gen_random_uuid(), 'saltines', 'Saltines (10 crackers)', 'Saltines (10 crackers)', 22.0, true),
  (gen_random_uuid(), 'fig_bar', 'Fig bar (twin-pack)', 'Fig bars (twin-pack)', 26.0, true),
  (gen_random_uuid(), 'sports_drink', 'Sports drink (1 cup)', 'Sports drink (1 cup)', 16.0, true),
  (gen_random_uuid(), 'energy_gel', 'Energy gel (1 packet)', 'Energy gels (1 packet)', 25.0, true),
  (gen_random_uuid(), 'rice_pudding', 'Rice pudding (1/2 cup)', 'Rice pudding (1/2 cup)', 30.0, true),
  (gen_random_uuid(), 'beet_juice', 'Beet juice (1 cup)', 'Beet juice (1 cup)', 18.0, true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Seed Data: carb_loading_food_meal_types (Food → Meal Type Associations)
-- ============================================================================

-- Breakfast Foods (meal_type_id = 1)
INSERT INTO carb_loading_food_meal_types (carb_loading_food_id, meal_type_id)
SELECT id, 1 FROM carb_loading_foods WHERE name IN (
  'cereal', 'oats', 'banana', 'bagel', 'toast', 'pancake', 'waffle', 'orange_juice', 'smoothie'
)
ON CONFLICT DO NOTHING;

-- Lunch Foods (meal_type_id = 2)
INSERT INTO carb_loading_food_meal_types (carb_loading_food_id, meal_type_id)
SELECT id, 2 FROM carb_loading_foods WHERE name IN (
  'pasta_marinara', 'rice', 'baked_potato', 'sweet_potato', 'beets', 'pizza', 'sandwich'
)
ON CONFLICT DO NOTHING;

-- Dinner Foods (meal_type_id = 3) - Same as lunch
INSERT INTO carb_loading_food_meal_types (carb_loading_food_id, meal_type_id)
SELECT id, 3 FROM carb_loading_foods WHERE name IN (
  'pasta_marinara', 'rice', 'baked_potato', 'sweet_potato', 'beets', 'pizza', 'sandwich'
)
ON CONFLICT DO NOTHING;

-- Snack Foods (meal_type_id = 4)
INSERT INTO carb_loading_food_meal_types (carb_loading_food_id, meal_type_id)
SELECT id, 4 FROM carb_loading_foods WHERE name IN (
  'dates', 'berries', 'apple', 'pretzels', 'graham_crackers', 'saltines',
  'fig_bar', 'sports_drink', 'energy_gel', 'rice_pudding', 'beet_juice', 'banana'
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
  food_count INTEGER;
  association_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO food_count FROM carb_loading_foods WHERE is_default = true;
  SELECT COUNT(*) INTO association_count FROM carb_loading_food_meal_types;

  RAISE NOTICE 'Seed data migration completed successfully';
  RAISE NOTICE 'Default carb loading foods inserted: %', food_count;
  RAISE NOTICE 'Food-to-meal associations created: %', association_count;

  -- Expected counts
  IF food_count < 27 THEN
    RAISE WARNING 'Expected at least 27 default foods, but found %', food_count;
  END IF;

  IF association_count < 35 THEN
    RAISE WARNING 'Expected at least 35 food-meal associations, but found %', association_count;
  END IF;
END $$;
