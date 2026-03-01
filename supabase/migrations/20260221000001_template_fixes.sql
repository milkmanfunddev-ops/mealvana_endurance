-- ============================================================================
-- Template Fixes Migration
--
-- D4: Fix egg sodium (was 186mg, should be 62mg for boiled/poached)
-- F:  Expand during_run food pool by tagging existing foods + adding stroopwafel
-- ============================================================================

-- ============================================================================
-- D4: Fix egg sodium value
-- USDA: 1 large egg (boiled/poached) = 62mg sodium
-- Previous value of 186mg was for scrambled/fried preparation
-- ============================================================================

UPDATE template_foods
SET sodium_mg = 62,
    display_name = 'Egg (boiled/poached)',
    updated_at = now()
WHERE name = 'egg';

-- Also update the egg data embedded in templates.foods JSONB
UPDATE templates
SET foods = (
  SELECT jsonb_agg(
    CASE
      WHEN (f->>'food_name') = 'egg'
      THEN f || '{"sodium_mg": 62}'::jsonb
      ELSE f
    END
  )
  FROM jsonb_array_elements(foods) AS f
),
updated_at = now()
WHERE EXISTS (
  SELECT 1 FROM jsonb_array_elements(foods) AS f
  WHERE (f->>'food_name') = 'egg'
);

-- Recalculate total_sodium_mg for affected templates
UPDATE templates
SET total_sodium_mg = (
  SELECT COALESCE(SUM(
    (f->>'sodium_mg')::numeric * (f->>'default_servings')::numeric
  ), 0)
  FROM jsonb_array_elements(foods) AS f
)
WHERE EXISTS (
  SELECT 1 FROM jsonb_array_elements(foods) AS f
  WHERE (f->>'food_name') = 'egg'
);

-- ============================================================================
-- F: Expand during_run food pool
-- Tag 8 existing foods with during_run category and set max_servings_during
-- ============================================================================

-- banana: already a common race fuel, quick energy
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END,
max_servings_during = 3
WHERE name = 'banana';

-- dates: high glycemic, quick carbs, popular race fuel
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END,
max_servings_during = 3
WHERE name = 'dates';

-- honey: pure simple carbs, great for race fuel
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END,
max_servings_during = 3
WHERE name = 'honey';

-- raisins: portable, easy to eat on the move
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END,
max_servings_during = 3
WHERE name = 'raisins';

-- pretzels: salty carbs, good for sodium + fuel
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END,
max_servings_during = 3
WHERE name = 'pretzels';

-- fig_bar: popular ultra/marathon aid station food
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END,
max_servings_during = 3
WHERE name = 'fig_bar';

-- applesauce_pouch: easy to consume while moving
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END,
max_servings_during = 3
WHERE name = 'applesauce_pouch';

-- graham_crackers: light, quick carbs
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END,
max_servings_during = 3
WHERE name = 'graham_crackers';

-- ============================================================================
-- F: Insert stroopwafel (Energy Waffle)
-- Popular cycling/running race fuel, widely available
-- Nutrition per waffle: 150 cal, 21g carbs, 2g protein, 7g fat, 80mg sodium
-- ============================================================================

INSERT INTO template_foods (
  name, display_name, display_name_plural, serving_size, serving_weight_g,
  calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml,
  allergens, digestion_speed, product_type,
  categories, activity_types,
  is_liquid, is_drink_pool, drink_pool_phases,
  is_electrolyte, is_essential,
  max_servings_before, max_servings_during, max_servings_after,
  to_exclude_from_solver, show_in_preferences,
  excluded_diets
) VALUES (
  'stroopwafel', 'Energy Waffle', 'Energy Waffles', '1 waffle', 30.0,
  150, 21.0, 2.0, 7.0, 0.0, 80.0, 0.0,
  '{gluten,dairy}', 'fast', 'real_food',
  '{before_run,during_run}', '{running,cycling,swimming}',
  false, false, '{}',
  false, false,
  3, 3, 0,
  false, true,
  '{vegan}'
)
ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  display_name_plural = EXCLUDED.display_name_plural,
  serving_size = EXCLUDED.serving_size,
  serving_weight_g = EXCLUDED.serving_weight_g,
  calories = EXCLUDED.calories,
  carbs_g = EXCLUDED.carbs_g,
  protein_g = EXCLUDED.protein_g,
  fat_g = EXCLUDED.fat_g,
  fiber_g = EXCLUDED.fiber_g,
  sodium_mg = EXCLUDED.sodium_mg,
  fluid_ml = EXCLUDED.fluid_ml,
  allergens = EXCLUDED.allergens,
  digestion_speed = EXCLUDED.digestion_speed,
  product_type = EXCLUDED.product_type,
  categories = EXCLUDED.categories,
  activity_types = EXCLUDED.activity_types,
  is_liquid = EXCLUDED.is_liquid,
  max_servings_before = EXCLUDED.max_servings_before,
  max_servings_during = EXCLUDED.max_servings_during,
  max_servings_after = EXCLUDED.max_servings_after,
  to_exclude_from_solver = EXCLUDED.to_exclude_from_solver,
  show_in_preferences = EXCLUDED.show_in_preferences,
  excluded_diets = EXCLUDED.excluded_diets,
  updated_at = now();
