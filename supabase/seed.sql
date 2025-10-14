-- Mealvana Endurance Test Seed Data
-- This file populates the local Supabase database with test data for edge function testing
-- Simplified to match actual Supabase schema

-- Clear existing test data (be careful in production!)
DELETE FROM food_categories WHERE food_id IN (
  SELECT id FROM foods WHERE name LIKE 'TEST:%'
);
DELETE FROM food_preferences WHERE food_id IN (
  SELECT id FROM foods WHERE name LIKE 'TEST:%'
);
DELETE FROM foods WHERE name LIKE 'TEST:%';
DELETE FROM user_profiles WHERE email LIKE 'test%@mealvana.com';

-- Ensure product types exist
INSERT INTO product_types (code, name, name_plural, sort_order) VALUES
  ('GEL', 'Energy Gel', 'Energy Gels', 1),
  ('BAR', 'Energy Bar', 'Energy Bars', 2),
  ('DRINK', 'Sports Drink', 'Sports Drinks', 3),
  ('CHEW', 'Energy Chew', 'Energy Chews', 4),
  ('WHOLE', 'Whole Food', 'Whole Foods', 5),
  ('SUPP', 'Supplement', 'Supplements', 6),
  ('SNACK', 'Snack', 'Snacks', 7)
ON CONFLICT (code) DO NOTHING;

-- Ensure categories exist
INSERT INTO categories (id, name) VALUES
  (1, 'Before Run'),
  (2, 'During Run'),
  (3, 'After Run')
ON CONFLICT DO NOTHING;

-- Insert test foods (matching actual schema)
INSERT INTO foods (
  name, display_name, display_name_plural, description,
  serving_description, serving_amount, serving_size,
  calories_per_serving, carbs_per_serving, protein_per_serving,
  fat_per_serving, sodium_mg, potassium_mg, caffeine_mg,
  fluid_ml_per_serving,
  max_servings_before, max_servings_during, max_servings_after,
  show_in_preferences, is_essential, is_electrolyte,
  to_exclude_from_solver, product_type_id
) VALUES
  -- Whole foods
  ('TEST: Banana', 'banana', 'bananas',
   'Medium banana, rich in potassium and easily digestible carbohydrates',
   '1 medium', 1.0, '118g',
   105, 27.0, 1.3, 0.4, 1, 422, NULL, 88.0,
   2, 1, 2,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'WHOLE' LIMIT 1)),

  ('TEST: Oatmeal', 'oatmeal', 'oatmeal',
   'Steel cut oats, slow-releasing carbohydrates',
   '1 cup cooked', 1.0, '234g',
   158, 27.0, 6.0, 3.2, 115, NULL, NULL, 185.0,
   2, 0, 1,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'WHOLE' LIMIT 1)),

  -- Gels (Essential items)
  ('TEST: GU Energy Gel', 'gel', 'gels',
   'Quick-absorbing energy gel with electrolytes',
   '1 packet', 1.0, '32g',
   100, 22.0, 0, 0, 60, 40, 20, 0,
   1, 4, 0,
   true, true, false, false,
   (SELECT id FROM product_types WHERE code = 'GEL' LIMIT 1)),

  -- Bars (with barcodes as part of name for testing)
  ('TEST: Clif Bar', 'bar', 'bars',
   'Energy bar with organic ingredients',
   '1 bar', 1.0, '68g',
   250, 45.0, 9.0, 6.0, 200, 250, NULL, 0,
   1, 2, 1,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'BAR' LIMIT 1)),

  ('TEST: Fig Bar (047495112900)', 'fig bar', 'fig bars',
   'Nature''s Bakery Fig Bar - Barcode: 047495112900',
   '1 bar', 1.0, '57g',
   200, 38.0, 3.0, 5.0, 75, NULL, NULL, 0,
   2, 1, 1,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'BAR' LIMIT 1)),

  ('TEST: Pure Protein Bar (749826001951)', 'protein bar', 'protein bars',
   'High protein recovery bar - Barcode: 749826001951',
   '1 bar', 1.0, '50g',
   190, 17.0, 19.0, 6.0, 150, NULL, NULL, 0,
   0, 0, 2,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'BAR' LIMIT 1)),

  -- Drinks (Including essential electrolyte drinks)
  ('TEST: Gatorade', 'sports drink', 'sports drinks',
   'Electrolyte replacement beverage',
   '8 fl oz', 8.0, '240ml',
   50, 14.0, 0, 0, 110, 30, NULL, 240.0,
   2, 4, 2,
   true, true, true, false,
   (SELECT id FROM product_types WHERE code = 'DRINK' LIMIT 1)),

  ('TEST: Coconut Water', 'coconut water', 'coconut water',
   'Natural electrolyte beverage',
   '8 fl oz', 8.0, '240ml',
   45, 11.0, 0.5, 0, 25, 470, NULL, 240.0,
   2, 2, 2,
   true, false, true, false,
   (SELECT id FROM product_types WHERE code = 'DRINK' LIMIT 1)),

  -- Chews
  ('TEST: Clif Shot Bloks', 'energy chew', 'energy chews',
   'Organic energy chews with electrolytes',
   '3 pieces', 3.0, '30g',
   100, 24.0, 0, 0, 70, 20, NULL, 0,
   1, 3, 0,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'CHEW' LIMIT 1)),

  -- Snacks
  ('TEST: Honey Stinger Waffle', 'waffle', 'waffles',
   'Organic honey waffle for quick energy',
   '1 waffle', 1.0, '30g',
   140, 21.0, 1.0, 6.0, 40, NULL, NULL, 0,
   1, 2, 0,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'SNACK' LIMIT 1)),

  -- Supplements
  ('TEST: Nuun Electrolyte Tablet', 'electrolyte tablet', 'electrolyte tablets',
   'Effervescent electrolyte tablet',
   '1 tablet in 16oz water', 1.0, '5g',
   10, 2.0, 0, 0, 300, 150, NULL, 480.0,
   1, 2, 2,
   true, false, true, false,
   (SELECT id FROM product_types WHERE code = 'SUPP' LIMIT 1)),

  ('TEST: UCAN Energy Powder', 'energy powder', 'energy powder',
   'Slow-release carbohydrate drink mix',
   '1 scoop in 12oz water', 1.0, '55g',
   110, 27.0, 0, 0, 110, 60, NULL, 360.0,
   1, 2, 1,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'SUPP' LIMIT 1)),

  ('TEST: Dates', 'date', 'dates',
   'Medjool dates for natural energy',
   '2 dates', 2.0, '40g',
   110, 30.0, 0.7, 0.1, 1, 270, NULL, 0,
   2, 1, 1,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'WHOLE' LIMIT 1)),

  ('TEST: Orange Slices', 'orange', 'oranges',
   'Fresh orange slices for quick energy and hydration',
   '1 medium orange', 1.0, '154g',
   62, 15.0, 1.2, 0.2, 0, 237, NULL, 110.0,
   1, 1, 2,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'WHOLE' LIMIT 1)),

  ('TEST: Peanut Butter Toast', 'toast', 'toasts',
   'Whole wheat toast with peanut butter',
   '1 slice with 2 tbsp PB', 1.0, '70g',
   280, 28.0, 11.0, 16.0, 280, NULL, NULL, 0,
   1, 0, 1,
   true, false, false, false,
   (SELECT id FROM product_types WHERE code = 'WHOLE' LIMIT 1));

-- Link foods to categories based on servings
-- Before Run foods (max_servings_before > 0)
INSERT INTO food_categories (food_id, category_id)
SELECT id, 1 FROM foods
WHERE name LIKE 'TEST:%' AND max_servings_before > 0;

-- During Run foods (max_servings_during > 0)
INSERT INTO food_categories (food_id, category_id)
SELECT id, 2 FROM foods
WHERE name LIKE 'TEST:%' AND max_servings_during > 0;

-- After Run foods (max_servings_after > 0)
INSERT INTO food_categories (food_id, category_id)
SELECT id, 3 FROM foods
WHERE name LIKE 'TEST:%' AND max_servings_after > 0;

-- Create test user profiles for various scenarios
INSERT INTO user_profiles (
  device_id, email, height_inches, weight_lbs,
  age, gender, fitness_level, race_experience,
  gut_training_level, gi_sensitivity_level
) VALUES
  -- Standard athlete
  ('test-device-001', 'test1@mealvana.com',
   70, 150, 30, 'male', 3, 'intermediate',
   'medium', 'low'),

  -- Beginner with sensitive stomach
  ('test-device-002', 'test2@mealvana.com',
   64, 130, 25, 'female', 2, 'beginner',
   'low', 'high'),

  -- Advanced ultra runner
  ('test-device-003', 'test3@mealvana.com',
   72, 165, 35, 'male', 5, 'advanced',
   'high', 'low'),

  -- Heavy athlete
  ('test-device-004', 'test4@mealvana.com',
   76, 200, 40, 'male', 3, 'intermediate',
   'medium', 'medium'),

  -- Lightweight runner
  ('test-device-005', 'test5@mealvana.com',
   62, 110, 28, 'female', 4, 'intermediate',
   'medium', 'low')
ON CONFLICT (device_id) DO NOTHING;

-- Create test food preferences
INSERT INTO food_preferences (
  user_profile_id, food_id, preference_level
)
SELECT
  up.id,
  f.id,
  CASE
    WHEN f.name = 'TEST: Banana' AND up.email = 'test1@mealvana.com' THEN 'liked'
    WHEN f.name = 'TEST: GU Energy Gel' AND up.email = 'test1@mealvana.com' THEN 'liked'
    WHEN f.name = 'TEST: Oatmeal' AND up.email = 'test1@mealvana.com' THEN 'disliked'
    WHEN f.name = 'TEST: Gatorade' AND up.email = 'test1@mealvana.com' THEN 'neutral'
    WHEN f.name = 'TEST: GU Energy Gel' AND up.email = 'test2@mealvana.com' THEN 'disliked'
    WHEN f.name = 'TEST: Banana' AND up.email = 'test2@mealvana.com' THEN 'liked'
    ELSE NULL
  END
FROM user_profiles up
CROSS JOIN foods f
WHERE up.email LIKE 'test%@mealvana.com'
  AND f.name LIKE 'TEST:%'
  AND (
    (up.email = 'test1@mealvana.com' AND f.name IN ('TEST: Banana', 'TEST: GU Energy Gel', 'TEST: Oatmeal', 'TEST: Gatorade'))
    OR (up.email = 'test2@mealvana.com' AND f.name IN ('TEST: GU Energy Gel', 'TEST: Banana'))
  )
ON CONFLICT DO NOTHING;

-- Verify seed data
DO $$
DECLARE
  test_food_count INT;
  test_user_count INT;
  test_pref_count INT;
BEGIN
  SELECT COUNT(*) INTO test_food_count FROM foods WHERE name LIKE 'TEST:%';
  SELECT COUNT(*) INTO test_user_count FROM user_profiles WHERE email LIKE 'test%@mealvana.com';
  SELECT COUNT(*) INTO test_pref_count FROM food_preferences WHERE user_profile_id IN (SELECT id FROM user_profiles WHERE email LIKE 'test%@mealvana.com');

  RAISE NOTICE 'Test seed data loaded:';
  RAISE NOTICE '  - % test foods', test_food_count;
  RAISE NOTICE '  - % test users', test_user_count;
  RAISE NOTICE '  - % test preferences', test_pref_count;
END $$;