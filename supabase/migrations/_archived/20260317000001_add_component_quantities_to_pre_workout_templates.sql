-- ============================================================================
-- Migration: Add component_quantities JSONB to pre_workout_templates
--
-- Purpose:
--   Store per-component serving proportions so the edge function can
--   "explode" composite templates into individual FoodResult items that
--   reference template_foods.  Key: component_food_name, Value: servings
--   of that component per 1 serving of the composite template.
--
--   Single-ingredient templates (Oatmeal, Energy Gel, Water, etc.) get
--   {"<name>": 1} so the explosion logic is uniform.
--
-- Date: 2026-03-17
-- ============================================================================

ALTER TABLE public.pre_workout_templates
  ADD COLUMN IF NOT EXISTS component_quantities JSONB DEFAULT '{}';

COMMENT ON COLUMN public.pre_workout_templates.component_quantities
  IS 'Per-component serving proportions. Key = template_foods.name, Value = servings of that component food per 1 serving of this template.';

-- ============================================================================
-- Populate component_quantities for all templates
-- ============================================================================

-- === FOOD TEMPLATES ===

-- Oatmeal: 1 serving = 0.5 cup dry oats = 1 serving oatmeal
UPDATE public.pre_workout_templates
  SET component_quantities = '{"oatmeal": 1}'
  WHERE name = 'Oatmeal' AND template_type = 'food';

-- Oatmeal + Raisins: 0.5 cup dry oats + 1 tbsp raisins
-- template_foods oatmeal = 1 serving (0.5 cup), raisins = 1 serving (2 tbsp) → use 0.5 tbsp raisins = 0.5 serving
UPDATE public.pre_workout_templates
  SET component_quantities = '{"oatmeal": 1, "raisins": 0.5}'
  WHERE name = 'Oatmeal + Raisins' AND template_type = 'food';

-- Cereal + Milk: 0.75 cup cereal + 0.5 cup milk
-- template_foods cereal = 1 serving (1 cup) → 0.75, milk = 1 serving (1 cup) → 0.5
UPDATE public.pre_workout_templates
  SET component_quantities = '{"cereal": 0.75, "milk": 0.5}'
  WHERE name = 'Cereal + Milk' AND template_type = 'food';

-- Toast + Jam: 1 slice toast + 0.5 tbsp jam
-- template_foods toast = 1 serving (1 slice) → 1, jam = 1 serving (1 tbsp) → 0.5
UPDATE public.pre_workout_templates
  SET component_quantities = '{"toast": 1, "jam": 0.5}'
  WHERE name = 'Toast + Jam' AND template_type = 'food';

-- Toast + Peanut Butter: 1 slice toast + 1 tbsp peanut butter
UPDATE public.pre_workout_templates
  SET component_quantities = '{"toast": 1, "peanut_butter": 1}'
  WHERE name = 'Toast + Peanut Butter' AND template_type = 'food';

-- Toast + PB + Jam: 1 slice toast + 1 tbsp PB + 0.5 tbsp jam
UPDATE public.pre_workout_templates
  SET component_quantities = '{"toast": 1, "peanut_butter": 1, "jam": 0.5}'
  WHERE name = 'Toast + PB + Jam' AND template_type = 'food';

-- Bagel + Jam: 0.5 bagel + 0.5 tbsp jam
-- template_foods bagel = 1 serving (1 large) → 0.5, jam = 1 serving (1 tbsp) → 0.5
UPDATE public.pre_workout_templates
  SET component_quantities = '{"bagel": 0.5, "jam": 0.5}'
  WHERE name = 'Bagel + Jam' AND template_type = 'food';

-- Bagel + PB: 0.5 bagel + 1 tbsp PB
UPDATE public.pre_workout_templates
  SET component_quantities = '{"bagel": 0.5, "peanut_butter": 1}'
  WHERE name = 'Bagel + Peanut Butter' AND template_type = 'food';

-- Bagel + PB + Jam: 0.5 bagel + 1 tbsp PB + 0.5 tbsp jam
UPDATE public.pre_workout_templates
  SET component_quantities = '{"bagel": 0.5, "peanut_butter": 1, "jam": 0.5}'
  WHERE name = 'Bagel + PB + Jam' AND template_type = 'food';

-- Bagel + Cream Cheese: 0.5 bagel + 1 tbsp cream cheese
UPDATE public.pre_workout_templates
  SET component_quantities = '{"bagel": 0.5, "cream_cheese": 1}'
  WHERE name = 'Bagel + Cream Cheese' AND template_type = 'food';

-- Rice Cake + Jam: 1 rice cake + 0.5 tbsp jam
UPDATE public.pre_workout_templates
  SET component_quantities = '{"rice_cake": 1, "jam": 0.5}'
  WHERE name = 'Rice Cake + Jam' AND template_type = 'food';

-- Rice Cake + PB: 1 rice cake + 0.5 tbsp PB
UPDATE public.pre_workout_templates
  SET component_quantities = '{"rice_cake": 1, "peanut_butter": 0.5}'
  WHERE name = 'Rice Cake + Peanut Butter' AND template_type = 'food';

-- Rice Cake + PB + Jam: 1 rice cake + 0.5 tbsp PB + 0.5 tbsp jam
UPDATE public.pre_workout_templates
  SET component_quantities = '{"rice_cake": 1, "peanut_butter": 0.5, "jam": 0.5}'
  WHERE name = 'Rice Cake + PB + Jam' AND template_type = 'food';

-- Yogurt + Granola: 0.5 cup yogurt + 2 tbsp granola
-- template_foods yogurt = 1 serving (1 cup) → 0.5, granola = 1 serving (¼ cup) → ~0.5 (2 tbsp ≈ ⅛ cup)
-- Actually 2 tbsp = 1/8 cup; ¼ cup = 4 tbsp. So 2 tbsp = 0.5 of ¼-cup serving
UPDATE public.pre_workout_templates
  SET component_quantities = '{"yogurt": 0.5, "granola": 0.5}'
  WHERE name = 'Yogurt + Granola' AND template_type = 'food';

-- Granola Bar: 1 bar
UPDATE public.pre_workout_templates
  SET component_quantities = '{"granola_bar": 1}'
  WHERE name = 'Granola Bar' AND template_type = 'food';

-- OJ + Toast: 4oz OJ + 1 slice toast
-- template_foods orange_juice = 1 serving (1 cup / 8oz) → 0.5
UPDATE public.pre_workout_templates
  SET component_quantities = '{"orange_juice": 0.5, "toast": 1}'
  WHERE name = 'OJ + Toast' AND template_type = 'food';

-- Smoothie (Fruit): 0.5 banana + 0.25 cup berries + 0.5 cup milk
-- template_foods banana = 1 serving (1 medium) → 0.5, blueberries = 1 serving (½ cup) → 0.5, milk = 1 serving (1 cup) → 0.5
UPDATE public.pre_workout_templates
  SET component_quantities = '{"banana": 0.5, "blueberries": 0.5, "milk": 0.5}'
  WHERE name ILIKE '%Smoothie%' AND template_type = 'food';

-- Energy Gel: 1 packet
UPDATE public.pre_workout_templates
  SET component_quantities = '{"energy_gel": 1}'
  WHERE name = 'Energy Gel' AND template_type = 'food';

-- Energy Chews: 1 packet
UPDATE public.pre_workout_templates
  SET component_quantities = '{"energy_chews": 1}'
  WHERE name = 'Energy Chews' AND template_type = 'food';

-- === DRINK TEMPLATES ===

-- Water: 1 cup
UPDATE public.pre_workout_templates
  SET component_quantities = '{"water": 1}'
  WHERE name = 'Water' AND template_type = 'drink';

-- Coconut Water: 1 cup
UPDATE public.pre_workout_templates
  SET component_quantities = '{"coconut_water": 1}'
  WHERE name = 'Coconut Water' AND template_type = 'drink';

-- Sports Drink: 1 cup
UPDATE public.pre_workout_templates
  SET component_quantities = '{"sports_drink": 1}'
  WHERE name = 'Sports Drink' AND template_type = 'drink';

-- === ELECTROLYTE TEMPLATES ===

-- Electrolyte Tablet: 1 tablet
UPDATE public.pre_workout_templates
  SET component_quantities = '{"electrolyte_tablet": 1}'
  WHERE name = 'Electrolyte Tablet' AND template_type = 'electrolyte';

-- Electrolyte Drink Mix: 1 scoop
UPDATE public.pre_workout_templates
  SET component_quantities = '{"electrolyte_drink_mix": 1}'
  WHERE name = 'Electrolyte Drink Mix' AND template_type = 'electrolyte';

-- ============================================================================
-- Backfill templates missing component_food_names (3 that had empty arrays)
-- ============================================================================

UPDATE public.pre_workout_templates
  SET component_food_names = '{bagel,peanut_butter}',
      component_quantities = '{"bagel": 0.5, "peanut_butter": 1}'
  WHERE name = 'Bagel + Peanut Butter' AND template_type = 'food'
  AND (component_food_names IS NULL OR component_food_names = '{}');

UPDATE public.pre_workout_templates
  SET component_food_names = '{toast,peanut_butter}',
      component_quantities = '{"toast": 1, "peanut_butter": 1}'
  WHERE name = 'Toast + Peanut Butter' AND template_type = 'food'
  AND (component_food_names IS NULL OR component_food_names = '{}');

UPDATE public.pre_workout_templates
  SET component_food_names = '{rice_cake,peanut_butter}',
      component_quantities = '{"rice_cake": 1, "peanut_butter": 0.5}'
  WHERE name = 'Rice Cake + Peanut Butter' AND template_type = 'food'
  AND (component_food_names IS NULL OR component_food_names = '{}');
