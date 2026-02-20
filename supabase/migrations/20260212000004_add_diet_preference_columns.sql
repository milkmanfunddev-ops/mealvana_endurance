-- ============================================================================
-- Migration: Add Diet/Preference Columns to Template System
--
-- Purpose: Enable diet filtering, food categorization, and meal chain support
--
-- Changes:
--   1. ALTER template_foods: excluded_diets, product_type, activity_types,
--      categories, show_in_preferences, is_essential, is_electrolyte,
--      requires_preparation, caffeine_mg, potassium_mg
--   2. ALTER templates: excluded_diets
--   3. UPDATE each food with correct diet/product_type values
--   4. Derive template excluded_diets from food unions
--
-- Date: 2026-02-12
-- ============================================================================

-- ============================================================================
-- ALTER template_foods
-- ============================================================================

ALTER TABLE public.template_foods
  ADD COLUMN IF NOT EXISTS excluded_diets TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS product_type TEXT DEFAULT 'real_food',
  ADD COLUMN IF NOT EXISTS activity_types TEXT[] DEFAULT '{running,cycling,swimming}',
  ADD COLUMN IF NOT EXISTS categories TEXT[] DEFAULT '{before_run}',
  ADD COLUMN IF NOT EXISTS show_in_preferences BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_essential BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_electrolyte BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS requires_preparation BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS caffeine_mg NUMERIC(6,1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS potassium_mg NUMERIC(6,1) DEFAULT 0;

-- ============================================================================
-- ALTER templates
-- ============================================================================

ALTER TABLE public.templates
  ADD COLUMN IF NOT EXISTS excluded_diets TEXT[] DEFAULT '{}';

-- ============================================================================
-- UPDATE template_foods with correct values
-- ============================================================================

-- Grains (contain gluten - excluded from paleo, keto, low_carb)
UPDATE public.template_foods SET
  excluded_diets = '{paleo,keto,low_carb}',
  product_type = 'real_food',
  requires_preparation = false
WHERE name IN ('white_bread', 'whole_wheat_bread', 'bagel_large', 'cereal', 'granola', 'graham_crackers', 'pretzels', 'saltines');

-- Oatmeal, rice, pasta, sweet_potato (require prep)
UPDATE public.template_foods SET
  excluded_diets = '{paleo,keto,low_carb}',
  product_type = 'real_food',
  requires_preparation = true
WHERE name IN ('oatmeal_cooked', 'pasta_cooked');

UPDATE public.template_foods SET
  excluded_diets = '{keto,low_carb}',
  product_type = 'real_food',
  requires_preparation = true
WHERE name IN ('white_rice_cooked', 'sweet_potato');

-- Fig bar (gluten, processed)
UPDATE public.template_foods SET
  excluded_diets = '{paleo,keto,low_carb}',
  product_type = 'bar',
  requires_preparation = false
WHERE name = 'fig_bar';

-- Energy bar (gluten, processed)
UPDATE public.template_foods SET
  excluded_diets = '{paleo,keto,low_carb}',
  product_type = 'bar',
  requires_preparation = false
WHERE name = 'energy_bar';

-- Pancake/waffle (contain eggs + dairy + gluten)
UPDATE public.template_foods SET
  excluded_diets = '{vegan,paleo,keto,low_carb}',
  product_type = 'real_food',
  requires_preparation = true
WHERE name IN ('pancake_medium', 'toaster_waffle');

-- Superhero muffin (contains eggs + gluten)
UPDATE public.template_foods SET
  excluded_diets = '{vegan,paleo,keto,low_carb}',
  product_type = 'real_food',
  requires_preparation = false
WHERE name = 'superhero_muffin';

-- Dairy products (excluded from vegan, paleo)
UPDATE public.template_foods SET
  excluded_diets = '{vegan,paleo}',
  product_type = 'real_food',
  requires_preparation = false
WHERE name IN ('greek_yogurt', 'milk_whole', 'chocolate_milk');

-- Eggs (excluded from vegan)
UPDATE public.template_foods SET
  excluded_diets = '{vegan}',
  product_type = 'real_food',
  requires_preparation = true
WHERE name = 'scrambled_eggs';

-- Fruits (no exclusions, real food)
UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'real_food',
  requires_preparation = false
WHERE name IN ('banana', 'blueberries', 'mixed_berries', 'dates', 'raisins', 'applesauce', 'applesauce_cup');

-- Condiments (no exclusions)
UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'condiment',
  requires_preparation = false
WHERE name IN ('honey', 'jam', 'maple_syrup', 'marinara_sauce');

-- Nut butters (no exclusions beyond existing allergens)
UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'condiment',
  requires_preparation = false
WHERE name IN ('peanut_butter', 'almond_butter');

-- Rice cakes (no gluten, but excluded from keto/low_carb)
UPDATE public.template_foods SET
  excluded_diets = '{keto,low_carb}',
  product_type = 'real_food',
  requires_preparation = false
WHERE name = 'rice_cake_plain';

-- Sports products (no diet exclusions, specialized product types)
UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'sports_drink',
  is_electrolyte = true,
  requires_preparation = false
WHERE name = 'sports_drink';

UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'gel',
  requires_preparation = false
WHERE name = 'energy_gel';

UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'chew',
  requires_preparation = false
WHERE name = 'energy_chews';

UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'supplement',
  is_electrolyte = true,
  requires_preparation = false
WHERE name = 'electrolyte_drink';

-- Beverages
UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'beverage',
  requires_preparation = false
WHERE name = 'water';

UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'beverage',
  caffeine_mg = 95,
  requires_preparation = false
WHERE name = 'coffee';

UPDATE public.template_foods SET
  excluded_diets = '{}',
  product_type = 'beverage',
  requires_preparation = false
WHERE name IN ('orange_juice', 'fruit_smoothie');

-- ============================================================================
-- Derive template excluded_diets from food unions
-- ============================================================================

UPDATE public.templates t SET excluded_diets = COALESCE(
  (
    SELECT ARRAY(
      SELECT DISTINCT unnest(tf.excluded_diets)
      FROM jsonb_array_elements(t.foods) f
      JOIN public.template_foods tf ON tf.id = (f->>'food_id')::uuid
      WHERE tf.excluded_diets IS NOT NULL AND array_length(tf.excluded_diets, 1) > 0
    )
  ),
  '{}'
);
