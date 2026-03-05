-- ============================================================================
-- During-Phase Product Catalog Migration
-- ============================================================================
-- Adds min_servings_during column and updates template_foods for the
-- deterministic rule-based during solver.
--
-- Backward compatible: LP solver ignores min_servings_during, existing
-- plans are unaffected (totals stored at generation time).
-- ============================================================================

-- 1.1 Add min_servings_during column
ALTER TABLE template_foods
ADD COLUMN IF NOT EXISTS min_servings_during NUMERIC(4,1) DEFAULT 1.0;

-- ============================================================================
-- 1.2 Insert 3 new foods (ON CONFLICT upsert pattern)
-- ============================================================================

-- high_carb_drink_mix: 60g carbs per packet in 16oz water
INSERT INTO template_foods (
  id, name, display_name, display_name_plural, description,
  calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
  serving_size, serving_amount,
  is_active, is_liquid, is_electrolyte, is_essential, is_indivisible,
  product_type, categories, activity_types,
  default_during, min_servings_during,
  max_servings_before, max_servings_during, max_servings_after
) VALUES (
  gen_random_uuid(),
  'high_carb_drink_mix',
  'High-Carb Drink Mix',
  'packets High-Carb Drink Mix',
  'Concentrated carbohydrate drink mix (1 packet in 16oz water)',
  240, 60, 0, 0, 160, 500,
  '1 packet (in 16oz water)', 1,
  true, true, false, false, false,
  'drink_mix', '{during_run}', '{running,cycling}',
  true, 0.5,
  0, 5, 0
)
ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  display_name_plural = EXCLUDED.display_name_plural,
  description = EXCLUDED.description,
  calories = EXCLUDED.calories,
  carbs_g = EXCLUDED.carbs_g,
  protein_g = EXCLUDED.protein_g,
  fat_g = EXCLUDED.fat_g,
  sodium_mg = EXCLUDED.sodium_mg,
  fluid_ml = EXCLUDED.fluid_ml,
  serving_size = EXCLUDED.serving_size,
  serving_amount = EXCLUDED.serving_amount,
  is_liquid = EXCLUDED.is_liquid,
  is_electrolyte = EXCLUDED.is_electrolyte,
  is_essential = EXCLUDED.is_essential,
  is_indivisible = EXCLUDED.is_indivisible,
  product_type = EXCLUDED.product_type,
  categories = EXCLUDED.categories,
  activity_types = EXCLUDED.activity_types,
  default_during = EXCLUDED.default_during,
  min_servings_during = EXCLUDED.min_servings_during,
  max_servings_before = EXCLUDED.max_servings_before,
  max_servings_during = EXCLUDED.max_servings_during,
  max_servings_after = EXCLUDED.max_servings_after,
  updated_at = now();

-- electrolyte_drink_mix: 15g carbs, 400mg sodium per scoop
INSERT INTO template_foods (
  id, name, display_name, display_name_plural, description,
  calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
  serving_size, serving_amount,
  is_active, is_liquid, is_electrolyte, is_essential, is_indivisible,
  product_type, categories, activity_types,
  default_during, min_servings_during,
  max_servings_before, max_servings_during, max_servings_after
) VALUES (
  gen_random_uuid(),
  'electrolyte_drink_mix',
  'Electrolyte Drink Mix',
  'scoops Electrolyte Drink Mix',
  'Electrolyte drink mix (1 scoop in 16-20oz water)',
  60, 15, 0, 0, 400, 0,
  '1 scoop (in 16-20oz water)', 1,
  true, false, true, false, false,
  'supplement', '{during_run}', '{running,cycling}',
  true, 0.5,
  0, 3, 0
)
ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  display_name_plural = EXCLUDED.display_name_plural,
  description = EXCLUDED.description,
  calories = EXCLUDED.calories,
  carbs_g = EXCLUDED.carbs_g,
  protein_g = EXCLUDED.protein_g,
  fat_g = EXCLUDED.fat_g,
  sodium_mg = EXCLUDED.sodium_mg,
  fluid_ml = EXCLUDED.fluid_ml,
  serving_size = EXCLUDED.serving_size,
  serving_amount = EXCLUDED.serving_amount,
  is_liquid = EXCLUDED.is_liquid,
  is_electrolyte = EXCLUDED.is_electrolyte,
  is_essential = EXCLUDED.is_essential,
  is_indivisible = EXCLUDED.is_indivisible,
  product_type = EXCLUDED.product_type,
  categories = EXCLUDED.categories,
  activity_types = EXCLUDED.activity_types,
  default_during = EXCLUDED.default_during,
  min_servings_during = EXCLUDED.min_servings_during,
  max_servings_before = EXCLUDED.max_servings_before,
  max_servings_during = EXCLUDED.max_servings_during,
  max_servings_after = EXCLUDED.max_servings_after,
  updated_at = now();

-- energy_bar: 35g carbs, 150mg sodium per half bar (bike-only during)
-- IMPORTANT: Merges during_bike into existing categories rather than replacing
INSERT INTO template_foods (
  id, name, display_name, display_name_plural, description,
  calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
  serving_size, serving_amount,
  is_active, is_liquid, is_electrolyte, is_essential, is_indivisible,
  product_type, categories, activity_types,
  default_during, min_servings_during,
  max_servings_before, max_servings_during, max_servings_after
) VALUES (
  gen_random_uuid(),
  'energy_bar',
  'Energy Bar',
  'Energy Bars',
  'Half energy bar for sustained energy during cycling',
  140, 35, 3, 2, 150, 0,
  '1/2 bar', 1,
  true, false, false, false, false,
  'bar', '{before_run,during_bike}', '{running,cycling}',
  true, 0.5,
  4, 3, 4
)
ON CONFLICT (name) DO UPDATE SET
  display_name_plural = EXCLUDED.display_name_plural,
  -- Merge during_bike into existing categories (don't replace)
  categories = (
    SELECT array_agg(DISTINCT val)
    FROM unnest(
      COALESCE(template_foods.categories, '{}') || '{during_bike}'
    ) AS val
  ),
  -- Merge cycling into existing activity_types
  activity_types = (
    SELECT array_agg(DISTINCT val)
    FROM unnest(
      COALESCE(template_foods.activity_types, '{}') || '{cycling}'
    ) AS val
  ),
  default_during = true,
  min_servings_during = 0.5,
  updated_at = now();

-- ============================================================================
-- 1.3 Update existing foods to new specs
-- ============================================================================

-- sports_drink: 8oz -> 16oz serving (30g carbs, 200mg sodium, 480ml fluid)
UPDATE template_foods SET
  carbs_g = 30,
  sodium_mg = 200,
  fluid_ml = 480,
  calories = 120,
  serving_size = '1 bottle (16 oz)',
  display_name_plural = 'bottles Sports Drink',
  max_servings_during = 6,
  min_servings_during = 0.5,
  updated_at = now()
WHERE name = 'sports_drink';

-- water: 8oz -> 16oz serving (480ml fluid)
UPDATE template_foods SET
  fluid_ml = 480,
  serving_size = '1 bottle (16 oz)',
  display_name_plural = 'bottles Water',
  max_servings_during = 6,
  min_servings_during = 0.5,
  updated_at = now()
WHERE name = 'water';

-- energy_gel: standardize to 25g carbs, 55mg sodium, 20ml fluid
UPDATE template_foods SET
  carbs_g = 25,
  sodium_mg = 55,
  fluid_ml = 20,
  calories = 100,
  min_servings_during = 1,
  max_servings_during = 10,
  display_name_plural = 'packets Energy Gel',
  is_indivisible = true,
  updated_at = now()
WHERE name = 'energy_gel';

-- energy_chews: 25g carbs, 80mg sodium
UPDATE template_foods SET
  carbs_g = 25,
  sodium_mg = 80,
  calories = 100,
  min_servings_during = 0.5,
  max_servings_during = 5,
  serving_size = '1 packet (3-4 chews)',
  display_name_plural = 'packets Energy Chews',
  updated_at = now()
WHERE name = 'energy_chews';

-- electrolyte_tablet: 2g carbs, 300mg sodium
UPDATE template_foods SET
  carbs_g = 2,
  sodium_mg = 300,
  calories = 10,
  min_servings_during = 1,
  max_servings_during = 4,
  display_name_plural = 'tablets Electrolyte Tablet',
  is_indivisible = true,
  updated_at = now()
WHERE name = 'electrolyte_tablet';

-- stroopwafel: 22g carbs, 80mg sodium, add during_bike category
UPDATE template_foods SET
  carbs_g = 22,
  sodium_mg = 80,
  calories = 150,
  min_servings_during = 1,
  max_servings_during = 5,
  display_name_plural = 'Stroopwafels',
  is_indivisible = true,
  -- Merge during_bike into existing categories
  categories = (
    SELECT array_agg(DISTINCT val)
    FROM unnest(
      COALESCE(template_foods.categories, '{}') || '{during_bike}'
    ) AS val
    WHERE val IS NOT NULL
  ),
  updated_at = now()
WHERE name = 'stroopwafel';

-- ============================================================================
-- 1.4 Set default_during=false on non-core foods
-- ============================================================================
UPDATE template_foods SET
  default_during = false,
  updated_at = now()
WHERE name IN (
  'dates', 'raisins', 'pretzels', 'banana', 'honey',
  'fig_bar', 'graham_crackers', 'applesauce_pouch',
  'pickle_juice_shot', 'salt'
)
AND (default_during IS NULL OR default_during = true);
