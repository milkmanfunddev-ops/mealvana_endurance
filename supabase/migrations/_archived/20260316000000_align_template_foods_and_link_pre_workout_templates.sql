-- ============================================================================
-- Migration: Align template_foods names + Link pre_workout_templates
--
-- Purpose:
--   1. Rename mismatched template_foods to match pre_workout_template ingredients
--   2. Add component_food_names TEXT[] to pre_workout_templates
--   3. Populate component_food_names for all templates
--   4. Update show_in_preferences for curated food preferences UI
--
-- Date: 2026-03-16
-- ============================================================================

-- ============================================================================
-- STEP 1: Rename mismatched template_foods
-- ============================================================================

-- oats_dry → oatmeal (match pre_workout_template "Oatmeal" ingredients)
UPDATE public.template_foods
  SET name = 'oatmeal', updated_at = now()
  WHERE name = 'oats_dry'
  AND NOT EXISTS (SELECT 1 FROM public.template_foods WHERE name = 'oatmeal');

-- white_bread → toast (match pre_workout_template "Toast / Bread" ingredients)
UPDATE public.template_foods
  SET name = 'toast', updated_at = now()
  WHERE name = 'white_bread'
  AND NOT EXISTS (SELECT 1 FROM public.template_foods WHERE name = 'toast');

-- Update references in food_preferences table
UPDATE public.food_preferences SET food_name = 'oatmeal' WHERE food_name = 'oats_dry';
UPDATE public.food_preferences SET food_name = 'toast' WHERE food_name = 'white_bread';

-- ============================================================================
-- STEP 2: Add component_food_names column to pre_workout_templates
-- ============================================================================

ALTER TABLE public.pre_workout_templates
  ADD COLUMN IF NOT EXISTS component_food_names TEXT[] DEFAULT '{}';

COMMENT ON COLUMN public.pre_workout_templates.component_food_names
  IS 'Array of template_foods.name values that compose this template meal/drink';

-- ============================================================================
-- STEP 3: Populate component_food_names for all templates
-- ============================================================================

-- Food templates (based on base_category / name)
UPDATE public.pre_workout_templates SET component_food_names = '{oatmeal}'
  WHERE name = 'Oatmeal' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{oatmeal,raisins}'
  WHERE name = 'Oatmeal + Raisins' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{cereal,milk}'
  WHERE name = 'Cereal + Milk' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{toast,jam}'
  WHERE name = 'Toast + Jam' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{toast,peanut_butter}'
  WHERE name = 'Toast + Peanut Butter' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{toast,peanut_butter,jam}'
  WHERE name = 'Toast + PB + Jam' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{bagel,jam}'
  WHERE name = 'Bagel + Jam' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{bagel,peanut_butter}'
  WHERE name = 'Bagel + Peanut Butter' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{bagel,peanut_butter,jam}'
  WHERE name = 'Bagel + PB + Jam' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{bagel,cream_cheese}'
  WHERE name = 'Bagel + Cream Cheese' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{rice_cake,jam}'
  WHERE name = 'Rice Cake + Jam' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{rice_cake,peanut_butter}'
  WHERE name = 'Rice Cake + Peanut Butter' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{rice_cake,peanut_butter,jam}'
  WHERE name = 'Rice Cake + PB + Jam' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{yogurt,granola}'
  WHERE name = 'Yogurt + Granola' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{granola_bar}'
  WHERE name = 'Granola Bar' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{orange_juice,toast}'
  WHERE name = 'OJ + Toast' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{banana,blueberries,milk}'
  WHERE name ILIKE '%Smoothie%' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{energy_gel}'
  WHERE name = 'Energy Gel' AND template_type = 'food';

UPDATE public.pre_workout_templates SET component_food_names = '{energy_chews}'
  WHERE name = 'Energy Chews' AND template_type = 'food';

-- Drink templates
UPDATE public.pre_workout_templates SET component_food_names = '{water}'
  WHERE name = 'Water' AND template_type = 'drink';

UPDATE public.pre_workout_templates SET component_food_names = '{coconut_water}'
  WHERE name = 'Coconut Water' AND template_type = 'drink';

UPDATE public.pre_workout_templates SET component_food_names = '{sports_drink}'
  WHERE name = 'Sports Drink' AND template_type = 'drink';

-- Electrolyte templates
UPDATE public.pre_workout_templates SET component_food_names = '{electrolyte_tablet}'
  WHERE name = 'Electrolyte Tablet' AND template_type = 'electrolyte';

UPDATE public.pre_workout_templates SET component_food_names = '{electrolyte_drink_mix}'
  WHERE name = 'Electrolyte Drink Mix' AND template_type = 'electrolyte';

-- ============================================================================
-- STEP 4: Update show_in_preferences on template_foods
--
-- Curate representative foods users would want to express preferences on.
-- Set false for condiments/essentials/infrastructure.
-- ============================================================================

-- First reset all to false
UPDATE public.template_foods SET show_in_preferences = false;

-- Set true for key preference-worthy foods
UPDATE public.template_foods SET show_in_preferences = true
WHERE name IN (
  'oatmeal',         -- Oatmeal
  'bagel',           -- Bagel (includes large)
  'toast',           -- Toast / Bread
  'rice_cake',       -- Rice Cake
  'cereal',          -- Cereal
  'yogurt',          -- Yogurt
  'granola',         -- Granola
  'granola_bar',     -- Granola Bar
  'peanut_butter',   -- Peanut Butter
  'banana',          -- Banana
  'orange_juice',    -- Orange Juice
  'energy_gel',      -- Energy Gel
  'energy_chews',    -- Energy Chews
  'sports_drink',    -- Sports Drink
  'coconut_water',   -- Coconut Water
  'milk',            -- Milk
  'raisins',         -- Raisins
  'blueberries'      -- Blueberries (smoothie)
);
