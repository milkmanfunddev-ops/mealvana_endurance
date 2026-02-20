-- ============================================================================
-- Migration: Unify Food Tables — Extend template_foods for LP Solver
--
-- Purpose: Make template_foods THE unified food table by adding columns needed
-- by the LP solver (during/after phases). The `foods` table remains untouched
-- for backwards compatibility with v1 edge functions and old app versions.
--
-- Changes:
--   A1. Add LP solver columns to template_foods
--   A2. Add missing food items from foods table (8 items)
--   A3. Populate LP solver columns from foods data for overlapping items
--   A4. Set show_in_preferences = false for infrastructure items
--
-- Date: 2026-02-20
-- ============================================================================

-- ============================================================================
-- A1. Add missing LP solver columns to template_foods
-- ============================================================================

ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS max_servings_before INTEGER DEFAULT 4;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS max_servings_during INTEGER DEFAULT 4;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS max_servings_after INTEGER DEFAULT 4;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS to_exclude_from_solver BOOLEAN DEFAULT false;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS display_name_plural TEXT;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS image_address TEXT;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS serving_amount REAL;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS serving_unit TEXT;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS serving_qualifier TEXT;
ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS is_liquid BOOLEAN DEFAULT false;

-- Note: show_in_preferences and is_essential already exist on template_foods
-- Note: is_liquid was added in migration 20260220000006 but adding IF NOT EXISTS for safety

-- ============================================================================
-- A2. Add missing food items from foods table
-- These items exist in `foods` but not in `template_foods`.
-- They are needed for the LP solver during/after phases.
-- ============================================================================

INSERT INTO template_foods (
  name, display_name, serving_size, serving_weight_g,
  calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml,
  allergens, digestion_speed, product_type,
  categories, activity_types,
  is_liquid, is_drink_pool, drink_pool_phases,
  is_electrolyte, is_essential,
  max_servings_before, max_servings_during, max_servings_after,
  to_exclude_from_solver, show_in_preferences
) VALUES
  -- Coconut water: hydration + electrolytes recovery drink
  ('coconut_water', 'Coconut Water', '1 cup (8 oz)', 240.0,
   46, 9.0, 1.7, 0.5, 2.6, 252.0, 240.0,
   '{}', 'fast', 'beverage',
   '{before_run,after_run}', '{running,cycling,swimming}',
   true, true, '{meal,snack,top_up}',
   false, false,
   2, 0, 3,
   false, true),

  -- Pickle juice shot: electrolyte supplement
  ('pickle_juice_shot', 'Pickle Juice Shot', '1 shot (2.5 oz)', 74.0,
   0, 0.0, 0.0, 0.0, 0.0, 940.0, 70.0,
   '{}', 'fast', 'supplement',
   '{during_run}', '{running,cycling,swimming}',
   true, false, '{}',
   true, false,
   0, 2, 0,
   false, true),

  -- Protein bar: before/after recovery
  ('protein_bar', 'Protein Bar', '1 bar', 60.0,
   230, 24.0, 20.0, 8.0, 3.0, 200.0, 0.0,
   '{dairy,gluten}', 'slow', 'bar',
   '{before_run,after_run}', '{running,cycling,swimming}',
   false, false, '{}',
   false, false,
   2, 0, 2,
   false, true),

  -- Protein shake (ready-to-drink): after phase recovery
  ('protein_shake', 'Protein Shake (RTD)', '1 bottle (11 oz)', 325.0,
   150, 5.0, 25.0, 3.0, 0.0, 200.0, 325.0,
   '{dairy}', 'medium', 'beverage',
   '{after_run}', '{running,cycling,swimming}',
   true, false, '{}',
   false, false,
   0, 0, 2,
   false, true),

  -- Trail mix: before phase snack food
  ('trail_mix', 'Trail Mix', '1/4 cup', 40.0,
   175, 15.0, 5.0, 12.0, 2.0, 85.0, 0.0,
   '{peanuts,tree_nuts}', 'slow', 'real_food',
   '{before_run}', '{running,cycling,swimming}',
   false, false, '{}',
   false, false,
   3, 0, 2,
   false, true),

  -- Electrolyte tablet: sodium supplement during exercise
  ('electrolyte_tablet', 'Electrolyte Tablet', '1 tablet (in water)', 4.0,
   10, 1.0, 0.0, 0.0, 0.0, 350.0, 0.0,
   '{}', 'fast', 'supplement',
   '{during_run}', '{running,cycling,swimming}',
   false, false, '{}',
   true, false,
   0, 3, 0,
   false, true),

  -- Salt packet: essential sodium supplement
  ('salt', 'Salt', '1 packet', 1.0,
   0, 0.0, 0.0, 0.0, 0.0, 390.0, 0.0,
   '{}', 'fast', 'supplement',
   '{during_run,before_run,after_run}', '{running,cycling,swimming}',
   false, false, '{}',
   true, true,
   3, 3, 3,
   true, false),

  -- Sports drink mix: during phase carb + electrolyte
  ('sports_drink_mix', 'Sports Drink Mix', '1 serving (in water)', 22.0,
   80, 21.0, 0.0, 0.0, 0.0, 160.0, 0.0,
   '{}', 'fast', 'beverage',
   '{during_run,before_run}', '{running,cycling,swimming}',
   false, true, '{meal,snack,top_up}',
   false, false,
   2, 4, 0,
   false, true)

ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
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
  is_drink_pool = EXCLUDED.is_drink_pool,
  drink_pool_phases = EXCLUDED.drink_pool_phases,
  is_electrolyte = EXCLUDED.is_electrolyte,
  is_essential = EXCLUDED.is_essential,
  max_servings_before = EXCLUDED.max_servings_before,
  max_servings_during = EXCLUDED.max_servings_during,
  max_servings_after = EXCLUDED.max_servings_after,
  to_exclude_from_solver = EXCLUDED.to_exclude_from_solver,
  show_in_preferences = EXCLUDED.show_in_preferences;

-- ============================================================================
-- A3. Populate LP solver columns for existing template_foods
-- Set reasonable defaults based on existing categories
-- ============================================================================

-- Before-phase foods: allow 4 servings before, 0 during
UPDATE template_foods
SET max_servings_before = 4,
    max_servings_during = 0,
    max_servings_after = 2
WHERE 'before_run' = ANY(categories)
  AND NOT 'during_run' = ANY(categories)
  AND max_servings_before = 4  -- only update defaults
  AND name NOT IN ('salt', 'water', 'coffee', 'sports_drink', 'electrolyte_drink', 'coconut_water');

-- During-phase foods: allow servings during, reduce before
UPDATE template_foods
SET max_servings_before = 2,
    max_servings_during = 4,
    max_servings_after = 2
WHERE 'during_run' = ANY(categories)
  AND max_servings_during = 4  -- only update defaults
  AND name NOT IN ('salt', 'water', 'coffee', 'sports_drink', 'electrolyte_drink');

-- Gels and chews: higher during servings
UPDATE template_foods
SET max_servings_during = 6
WHERE name IN ('energy_gel', 'energy_chews')
  AND max_servings_during = 4;

-- Liquids/beverages: higher limits for hydration
UPDATE template_foods
SET max_servings_before = 3,
    max_servings_during = 6,
    max_servings_after = 3
WHERE is_liquid = true
  AND name NOT IN ('coffee', 'orange_juice', 'protein_shake');

-- Set display_name_plural for key items
UPDATE template_foods SET display_name_plural = 'slices White Bread' WHERE name = 'white_bread';
UPDATE template_foods SET display_name_plural = 'slices Whole Wheat Bread' WHERE name = 'whole_wheat_bread';
UPDATE template_foods SET display_name_plural = 'Bananas' WHERE name = 'banana';
UPDATE template_foods SET display_name_plural = 'cups Oatmeal' WHERE name = 'oatmeal_cooked';
UPDATE template_foods SET display_name_plural = 'packets Energy Gel' WHERE name = 'energy_gel';
UPDATE template_foods SET display_name_plural = 'packages Energy Chews' WHERE name = 'energy_chews';
UPDATE template_foods SET display_name_plural = 'bars Energy Bar' WHERE name = 'energy_bar';
UPDATE template_foods SET display_name_plural = 'cups Sports Drink' WHERE name = 'sports_drink';
UPDATE template_foods SET display_name_plural = 'cups Water' WHERE name = 'water';
UPDATE template_foods SET display_name_plural = 'cups Coffee' WHERE name = 'coffee';
UPDATE template_foods SET display_name_plural = 'Rice Cakes' WHERE name = 'rice_cake_plain';
UPDATE template_foods SET display_name_plural = 'Protein Bars' WHERE name = 'protein_bar';
UPDATE template_foods SET display_name_plural = 'cups Chocolate Milk' WHERE name = 'chocolate_milk';
UPDATE template_foods SET display_name_plural = 'cups Coconut Water' WHERE name = 'coconut_water';
UPDATE template_foods SET display_name_plural = 'shots Pickle Juice' WHERE name = 'pickle_juice_shot';
UPDATE template_foods SET display_name_plural = 'bottles Protein Shake' WHERE name = 'protein_shake';
UPDATE template_foods SET display_name_plural = 'portions Trail Mix' WHERE name = 'trail_mix';
UPDATE template_foods SET display_name_plural = 'tablets Electrolyte Tablet' WHERE name = 'electrolyte_tablet';

-- Set serving_amount to 1 for all items that don't have it yet
UPDATE template_foods
SET serving_amount = 1.0
WHERE serving_amount IS NULL;

-- ============================================================================
-- A4. Set show_in_preferences = false for infrastructure items
-- These are essential/behind-the-scenes foods not shown in preference UI
-- ============================================================================

UPDATE template_foods SET show_in_preferences = false
WHERE name IN ('water', 'salt', 'electrolyte_drink', 'electrolyte_tablet', 'marinara_sauce', 'saltines');

-- Ensure water and salt are marked essential
UPDATE template_foods SET is_essential = true
WHERE name IN ('water', 'salt');

-- ============================================================================
-- A5. Add categories for during/after phases to existing template_foods
-- Many items only had before_run category; they need during/after for LP solver
-- ============================================================================

-- Energy gel: add during_run category
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'during_run' = ANY(categories)
    THEN array_append(categories, 'during_run')
  ELSE categories
END
WHERE name IN ('energy_gel', 'energy_chews', 'sports_drink', 'electrolyte_drink', 'rice_cake_plain');

-- Recovery foods: add after_run category
UPDATE template_foods
SET categories = CASE
  WHEN NOT 'after_run' = ANY(categories)
    THEN array_append(categories, 'after_run')
  ELSE categories
END
WHERE name IN ('banana', 'chocolate_milk', 'greek_yogurt', 'energy_bar',
               'white_rice_cooked', 'pasta_cooked', 'sweet_potato', 'scrambled_eggs');

-- Liquid items: set is_liquid flag for items that should be true
UPDATE template_foods
SET is_liquid = true
WHERE name IN ('chocolate_milk', 'coconut_water', 'protein_shake', 'pickle_juice_shot',
               'fruit_smoothie')
  AND is_liquid = false;

-- ============================================================================
-- Done! template_foods now has all columns and data needed by the LP solver.
-- The foods table is UNTOUCHED for backwards compatibility.
-- ============================================================================
