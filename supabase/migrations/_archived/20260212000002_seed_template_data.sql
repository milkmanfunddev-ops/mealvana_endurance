-- ============================================================================
-- Migration: Seed Template Data
--
-- Purpose: Populate template_foods (44 items) and templates (41 templates)
-- Source: USDA FoodData Central + Notion "Pre-workout formula by Claude (v2)"
--
-- Date: 2026-02-12
-- ============================================================================

-- ============================================================================
-- SEED: template_foods (44 food items)
-- ============================================================================

INSERT INTO public.template_foods (name, display_name, serving_size, serving_weight_g, calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml, allergens, digestion_speed) VALUES
  ('white_bread', 'White Bread', '1 slice', 25.0, 66, 12.7, 1.8, 0.8, 0.6, 130.0, 0.0, '{gluten}', 'fast'),
  ('whole_wheat_bread', 'Whole Wheat Bread', '1 slice', 28.0, 69, 11.6, 3.6, 1.0, 1.9, 132.0, 0.0, '{gluten}', 'medium'),
  ('bagel_large', 'Bagel (large)', '1 large', 105.0, 275, 53.0, 11.0, 1.5, 2.3, 462.0, 0.0, '{gluten}', 'medium'),
  ('banana', 'Banana', '1 medium', 118.0, 105, 27.0, 1.3, 0.4, 3.1, 1.0, 88.0, '{}', 'fast'),
  ('oatmeal_cooked', 'Oatmeal (cooked)', '1 cup', 234.0, 166, 28.0, 6.0, 3.5, 4.0, 9.0, 200.0, '{gluten}', 'medium'),
  ('blueberries', 'Blueberries', '1 cup', 148.0, 85, 21.4, 1.1, 0.5, 3.6, 1.0, 125.0, '{}', 'fast'),
  ('mixed_berries', 'Mixed Berries', '1 cup', 140.0, 70, 17.0, 1.0, 0.5, 4.0, 1.0, 120.0, '{}', 'fast'),
  ('honey', 'Honey', '1 tbsp', 21.0, 64, 17.3, 0.1, 0.0, 0.0, 1.0, 4.0, '{}', 'fast'),
  ('peanut_butter', 'Peanut Butter', '1 tbsp', 16.0, 94, 3.6, 3.6, 8.2, 0.8, 73.0, 0.0, '{peanuts}', 'slow'),
  ('almond_butter', 'Almond Butter', '1 tbsp', 16.0, 98, 3.0, 3.4, 9.0, 0.6, 36.0, 0.0, '{tree_nuts}', 'slow'),
  ('jam', 'Jam/Jelly', '1 tbsp', 20.0, 56, 13.8, 0.1, 0.0, 0.2, 6.0, 6.0, '{}', 'fast'),
  ('sports_drink', 'Sports Drink', '1 cup (8 oz)', 240.0, 52, 14.0, 0.0, 0.0, 0.0, 110.0, 237.0, '{}', 'fast'),
  ('energy_gel', 'Energy Gel', '1 packet', 32.0, 100, 25.0, 0.0, 0.0, 0.0, 55.0, 20.0, '{}', 'fast'),
  ('energy_chews', 'Energy Chews', '1 package', 40.0, 100, 24.0, 0.0, 0.0, 0.0, 108.0, 0.0, '{}', 'fast'),
  ('energy_bar', 'Energy/Granola Bar', '1 bar', 40.0, 170, 28.0, 6.0, 6.0, 2.0, 105.0, 0.0, '{gluten}', 'medium'),
  ('rice_cake_plain', 'Rice Cake (plain)', '1 cake', 9.0, 35, 7.3, 0.7, 0.3, 0.4, 29.0, 0.0, '{}', 'fast'),
  ('applesauce', 'Applesauce (unsweetened)', '1 pouch (90g)', 90.0, 42, 11.0, 0.2, 0.0, 1.0, 3.0, 77.0, '{}', 'fast'),
  ('orange_juice', 'Orange Juice', '1 cup (8 oz)', 248.0, 112, 26.0, 1.7, 0.5, 0.5, 2.0, 219.0, '{}', 'fast'),
  ('water', 'Water', '1 cup (8 oz)', 240.0, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 240.0, '{}', 'fast'),
  ('coffee', 'Coffee (black)', '1 cup (8 oz)', 237.0, 2, 0.0, 0.3, 0.0, 0.0, 5.0, 237.0, '{}', 'fast'),
  ('chocolate_milk', 'Chocolate Milk', '1 cup (8 oz)', 250.0, 190, 26.0, 7.0, 8.0, 1.0, 150.0, 220.0, '{dairy}', 'medium'),
  ('milk_whole', 'Milk (whole)', '1 cup (8 oz)', 244.0, 149, 12.0, 8.0, 8.0, 0.0, 105.0, 220.0, '{dairy}', 'medium'),
  ('greek_yogurt', 'Greek Yogurt (plain)', '1 cup', 245.0, 220, 9.0, 20.0, 11.0, 0.0, 68.0, 200.0, '{dairy}', 'slow'),
  ('granola', 'Granola', '1/2 cup', 56.0, 262, 35.0, 6.0, 12.0, 3.5, 13.0, 0.0, '{gluten}', 'medium'),
  ('cereal', 'Cereal (corn flakes type)', '1 cup', 28.0, 100, 24.0, 2.0, 0.0, 1.0, 200.0, 0.0, '{gluten}', 'fast'),
  ('white_rice_cooked', 'White Rice (cooked)', '1 cup', 186.0, 206, 45.0, 4.3, 0.4, 0.6, 2.0, 125.0, '{}', 'medium'),
  ('pasta_cooked', 'Pasta (cooked, no sauce)', '1 cup', 140.0, 221, 43.2, 8.1, 1.3, 2.5, 1.0, 90.0, '{gluten}', 'medium'),
  ('sweet_potato', 'Sweet Potato (baked)', '1 medium', 114.0, 103, 24.0, 2.3, 0.1, 3.8, 41.0, 82.0, '{}', 'medium'),
  ('scrambled_eggs', 'Scrambled Eggs', '1 large egg', 61.0, 91, 1.0, 6.1, 6.7, 0.0, 171.0, 0.0, '{eggs}', 'slow'),
  ('pancake_medium', 'Pancake (medium)', '1 medium (6")', 77.0, 175, 22.0, 5.0, 7.0, 0.5, 226.0, 40.0, '{gluten,eggs,dairy}', 'medium'),
  ('toaster_waffle', 'Toaster Waffle', '1 waffle', 35.0, 95, 15.4, 2.0, 3.0, 0.5, 212.0, 10.0, '{gluten,eggs,dairy}', 'medium'),
  ('maple_syrup', 'Maple Syrup', '1 tbsp', 20.0, 52, 13.4, 0.0, 0.0, 0.0, 2.0, 5.0, '{}', 'fast'),
  ('fig_bar', 'Fig Bar (twin-pack)', '1 twin-pack (2 bars)', 56.0, 200, 38.0, 3.0, 6.0, 2.0, 120.0, 8.0, '{gluten}', 'medium'),
  ('graham_crackers', 'Graham Crackers', '2 sheets', 28.0, 118, 21.5, 2.0, 2.8, 0.9, 169.0, 0.0, '{gluten}', 'fast'),
  ('dates', 'Dates (Medjool)', '1 date', 24.0, 66, 18.0, 0.4, 0.0, 1.6, 0.0, 5.0, '{}', 'fast'),
  ('raisins', 'Raisins', '1 small box (1.5 oz)', 43.0, 129, 34.0, 1.3, 0.2, 1.6, 5.0, 7.0, '{}', 'fast'),
  ('pretzels', 'Pretzels', '1 oz', 28.0, 108, 23.0, 2.8, 1.0, 0.9, 385.0, 0.0, '{gluten}', 'fast'),
  ('fruit_smoothie', 'Fruit Smoothie', '1 cup (8 oz)', 245.0, 120, 27.0, 2.0, 0.5, 1.5, 20.0, 215.0, '{}', 'fast'),
  ('superhero_muffin', 'Superhero Muffin', '1 muffin', 85.0, 180, 25.0, 4.0, 7.0, 2.5, 155.0, 15.0, '{gluten,eggs}', 'medium'),
  ('electrolyte_drink', 'Electrolyte Drink Mix', '1 serving (in water)', 5.0, 10, 2.0, 0.0, 0.0, 0.0, 300.0, 0.0, '{}', 'fast'),
  ('marinara_sauce', 'Marinara Sauce', '1/2 cup', 125.0, 66, 10.0, 2.0, 2.0, 2.0, 577.0, 100.0, '{}', 'fast'),
  ('saltines', 'Saltines', '5 crackers', 15.0, 63, 10.6, 1.4, 1.7, 0.4, 135.0, 0.0, '{gluten}', 'fast'),
  ('applesauce_cup', 'Applesauce (1 cup)', '1 cup', 244.0, 102, 28.0, 0.4, 0.1, 2.7, 5.0, 214.0, '{}', 'fast')
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
  digestion_speed = EXCLUDED.digestion_speed;

-- ============================================================================
-- HELPER: Create a function to look up food_id by name for JSONB construction
-- ============================================================================

CREATE OR REPLACE FUNCTION public._tf_id(food_name TEXT)
RETURNS UUID AS $$
  SELECT id FROM public.template_foods WHERE name = food_name LIMIT 1;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- HELPER: Build a food JSONB item for a template
-- ============================================================================

CREATE OR REPLACE FUNCTION public._build_food_item(
  p_food_name TEXT,
  p_default_servings NUMERIC,
  p_min_servings NUMERIC,
  p_max_servings NUMERIC
) RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'food_id', tf.id,
    'food_name', tf.name,
    'display_name', tf.display_name,
    'serving_size', tf.serving_size,
    'default_servings', p_default_servings,
    'min_servings', p_min_servings,
    'max_servings', p_max_servings,
    'calories', tf.calories,
    'carbs_g', tf.carbs_g,
    'protein_g', tf.protein_g,
    'fat_g', tf.fat_g,
    'sodium_mg', tf.sodium_mg,
    'fluid_ml', tf.fluid_ml
  )
  FROM public.template_foods tf
  WHERE tf.name = p_food_name
  LIMIT 1;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- SEED: templates (41 templates)
-- ============================================================================

-- Helper function to slugify template names
CREATE OR REPLACE FUNCTION public._slugify(input TEXT)
RETURNS TEXT AS $$
  SELECT lower(regexp_replace(regexp_replace(input, '[^a-zA-Z0-9\s-]', '', 'g'), '\s+', '-', 'g'));
$$ LANGUAGE sql IMMUTABLE;

-- ---- Template 1: Bagel (half) + Banana + Sports Drink ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Bagel (half) + Banana + Sports Drink',
  'bagel-half-banana-sports-drink',
  'before', '30-60 min', 30, 60, 'top_up', 'Bagel', 'fast', '{gluten}',
  '54kg: half bagel + 1 banana + 1 cup drink = 68g. 73kg: half bagel + 1.5 bananas + 1 cup drink = 82g. 91kg: 1 bagel + 1 banana + 1 cup drink = 96g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('bagel_large', 0.5, 0.5, 1)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('sports_drink', 1, 1, 2))
  ) AS t(item)),
  'validated', 1
);

-- ---- Template 2: Oatmeal + Berries + Water ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Oatmeal + Berries + Water',
  'oatmeal-berries-water',
  'before', '1-2 hours', 60, 120, 'snack', 'Oatmeal', 'medium', '{gluten}',
  '54kg: 0.5 cup oatmeal + 0.5 cup berries = 26g. 73kg: 1 cup oatmeal + 1 cup berries = 52g. 91kg: 1.5 cups oatmeal + 1 cup berries = 67g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('oatmeal_cooked', 1, 0.5, 1.5)),
    (public._build_food_item('mixed_berries', 1, 0.5, 1)),
    (public._build_food_item('water', 2, 1, 2))
  ) AS t(item)),
  'validated', 2
);

-- ---- Template 3: Toast + Honey + Banana + Water ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Toast + Honey + Banana + Water',
  'toast-honey-banana-water',
  'before', '30-60 min', 30, 60, 'top_up', 'Toast / Bread', 'fast', '{gluten}',
  '54kg: 1 toast + 1 tbsp honey + 1 banana = 61g. 73kg: 2 toasts + 1 tbsp honey + 1 banana = 78g. 91kg: 2 toasts + 2 tbsp honey + 2 bananas = 122g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('white_bread', 1, 1, 3)),
    (public._build_food_item('honey', 1, 1, 2)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('water', 2, 1, 2))
  ) AS t(item)),
  'validated', 3
);

-- ---- Template 4: Energy Gel + Water (version A) ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Energy Gel + Water (version A)',
  'energy-gel-water-a',
  'before', '< 30 min', 0, 30, 'top_up', 'Energy Gel', 'fast', '{}',
  '54kg: 1 gel (25g). 73kg: 1.5 gels (38g). 91kg: 2 gels (50g).',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('energy_gel', 1, 1, 2)),
    (public._build_food_item('water', 2, 1, 2))
  ) AS t(item)),
  'validated', 4
);

-- ---- Template 5: Greek Yogurt + Granola + Banana + Honey ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Greek Yogurt + Granola + Banana + Honey',
  'greek-yogurt-granola-banana-honey',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Yogurt', 'medium', '{dairy,gluten}',
  '54kg: 0.75 cup yogurt + 1/3 cup granola + banana + honey (69g); 91kg: 1.5 cups yogurt + 0.75 cup granola + banana + 1.5 tbsp honey (115g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('greek_yogurt', 1, 0.75, 1.5)),
    (public._build_food_item('granola', 1, 0.5, 1.5)),
    (public._build_food_item('banana', 1, 1, 1)),
    (public._build_food_item('honey', 1, 1, 1.5))
  ) AS t(item)),
  'validated', 5
);

-- ---- Template 6: Rice Cakes + Honey ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Rice Cakes + Honey',
  'rice-cakes-honey',
  'before', '30-60 min', 30, 60, 'top_up', 'Rice Cakes', 'fast', '{}',
  '54kg: 2 rice cakes + honey (32g); 91kg: 3 rice cakes + 1.5 tbsp honey (49g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('rice_cake_plain', 2, 2, 3)),
    (public._build_food_item('honey', 1, 1, 1.5))
  ) AS t(item)),
  'validated', 6
);

-- ---- Template 7: Applesauce + Water ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Applesauce + Water',
  'applesauce-water',
  'before', '< 30 min', 0, 30, 'top_up', 'Applesauce', 'fast', '{}',
  '54kg: 2 pouches (28g). 73kg: 3 pouches (42g). 91kg: 4 pouches (56g).',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('applesauce', 2, 2, 4)),
    (public._build_food_item('water', 1, 1, 2))
  ) AS t(item)),
  'validated', 7
);

-- ---- Template 8: Rice Cakes + Banana + Honey ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Rice Cakes + Banana + Honey',
  'rice-cakes-banana-honey',
  'before', '30-60 min', 30, 60, 'top_up', 'Rice Cakes', 'fast', '{}',
  '54kg: 2 rice cakes + banana + 0.5 tbsp honey (51g); 91kg: 3 rice cakes + banana + 1.5 tbsp honey (74g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('rice_cake_plain', 2, 2, 3)),
    (public._build_food_item('banana', 1, 1, 1)),
    (public._build_food_item('honey', 1, 0.5, 1.5))
  ) AS t(item)),
  'validated', 8
);

-- ---- Template 9: Rice + Banana + Chocolate Milk ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Rice + Banana + Chocolate Milk',
  'rice-banana-chocolate-milk',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Rice', 'medium', '{dairy}',
  '54kg: 0.75 cup rice + banana + 0.75 cup choc milk (76g); 91kg: 1.25 cups rice + banana + 1.25 cups choc milk (123g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('white_rice_cooked', 1, 0.75, 1.25)),
    (public._build_food_item('banana', 1, 1, 1)),
    (public._build_food_item('chocolate_milk', 1, 0.75, 1.25))
  ) AS t(item)),
  'validated', 9
);

-- ---- Template 10: Oatmeal + Eggs + Toast + OJ ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Oatmeal + Eggs + Toast + OJ',
  'oatmeal-eggs-toast-oj',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Oatmeal', 'medium', '{gluten,eggs}',
  '54kg: 0.75 cup oatmeal + 1 egg + toast + OJ (78g carbs); 91kg: 1.5 cups oatmeal + 2 eggs + 2 slices toast + OJ (127g carbs)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('oatmeal_cooked', 1, 0.75, 1.5)),
    (public._build_food_item('scrambled_eggs', 2, 1, 2)),
    (public._build_food_item('white_bread', 1, 1, 2)),
    (public._build_food_item('orange_juice', 1, 1, 1))
  ) AS t(item)),
  'validated', 10
);

-- ---- Template 11: Oatmeal + Banana + Toast + Orange Juice ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Oatmeal + Banana + Toast + Orange Juice',
  'oatmeal-banana-toast-oj',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Oatmeal', 'medium', '{gluten}',
  '54kg: 1 cup oatmeal + 1 banana + 1 toast + 1 cup OJ = 100g. 73kg: 1.5 cups + 1 banana + 1 toast + 1 cup OJ = 130g. 91kg: 2 cups + 2 bananas + 2 toasts + 1 cup OJ = 187g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('oatmeal_cooked', 1, 1, 2)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('white_bread', 1, 1, 2)),
    (public._build_food_item('orange_juice', 1, 1, 1))
  ) AS t(item)),
  'validated', 11
);

-- ---- Template 12: Oatmeal + Blueberries + Honey + Toast ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Oatmeal + Blueberries + Honey + Toast',
  'oatmeal-blueberries-honey-toast',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Oatmeal', 'medium', '{gluten}',
  '54kg: 1 cup oatmeal + 0.75 cup berries + 1.5 tbsp honey + toast (78g); 91kg: 2 cups oatmeal + 1 cup berries + 2 tbsp honey + 2 slices toast (128g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('oatmeal_cooked', 1.5, 1, 2)),
    (public._build_food_item('blueberries', 1, 0.75, 1)),
    (public._build_food_item('honey', 2, 1.5, 2)),
    (public._build_food_item('white_bread', 1, 1, 2))
  ) AS t(item)),
  'validated', 12
);

-- ---- Template 13: Bagel with Jam ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Bagel with Jam',
  'bagel-with-jam',
  'before', '30-60 min', 30, 60, 'top_up', 'Bagel', 'fast', '{gluten}',
  '54kg: 0.75 bagel + 1.5 tbsp jam (62g); 91kg: 1.25 bagels + 2.5 tbsp jam (103g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('bagel_large', 1, 0.75, 1.25)),
    (public._build_food_item('jam', 2, 1.5, 2.5))
  ) AS t(item)),
  'validated', 13
);

-- ---- Template 14: Smoothie + Toast ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Smoothie + Toast',
  'smoothie-toast',
  'before', '1-2 hours', 60, 120, 'snack', 'Smoothie', 'fast', '{gluten}',
  '54kg: 1 cup smoothie + 1 slice toast (44g); 91kg: 1.5 cups smoothie + 2 slices toast (76g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('fruit_smoothie', 1, 1, 1.5)),
    (public._build_food_item('white_bread', 2, 1, 2))
  ) AS t(item)),
  'validated', 14
);

-- ---- Template 15: Oatmeal with Banana + Honey ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Oatmeal with Banana + Honey',
  'oatmeal-banana-honey',
  'before', '1-2 hours', 60, 120, 'snack', 'Oatmeal', 'medium', '{gluten}',
  '54kg: 0.75 cup oatmeal + banana + honey (57g); 91kg: 1.25 cups oatmeal + banana + 1.5 tbsp honey (91g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('oatmeal_cooked', 1, 0.75, 1.25)),
    (public._build_food_item('banana', 1, 1, 1)),
    (public._build_food_item('honey', 1, 1, 1.5))
  ) AS t(item)),
  'validated', 15
);

-- ---- Template 16: Bagel + PB + Banana + Coffee (version A) ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Bagel + Peanut Butter + Banana + Coffee (version A)',
  'bagel-pb-banana-coffee-a',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Bagel', 'medium', '{gluten,peanuts}',
  '54kg: 1 bagel + 1 tbsp PB + 1 banana = 86g. 73kg: 1 bagel + 2 tbsp PB + 1 banana = 89g. 91kg: 1 bagel + 2 tbsp PB + 2 bananas = 116g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('bagel_large', 1, 1, 1)),
    (public._build_food_item('peanut_butter', 2, 1, 2)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('coffee', 1, 1, 1)),
    (public._build_food_item('water', 1, 1, 1))
  ) AS t(item)),
  'validated', 16
);

-- ---- Template 17: Bagel + PB + Banana + Coffee (version B) ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Bagel + Peanut Butter + Banana + Coffee (version B)',
  'bagel-pb-banana-coffee-b',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Bagel', 'medium', '{gluten,peanuts}',
  '54kg: 0.75 bagel + 1 tbsp PB + banana + coffee (73g); 91kg: 1.25 bagels + 2 tbsp PB + banana + coffee (112g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('bagel_large', 1, 0.75, 1.25)),
    (public._build_food_item('peanut_butter', 2, 1, 2)),
    (public._build_food_item('banana', 1, 1, 1)),
    (public._build_food_item('coffee', 1, 1, 1))
  ) AS t(item)),
  'validated', 17
);

-- ---- Template 18: Granola Bar + Banana + Sports Drink ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Granola Bar + Banana + Sports Drink',
  'granola-bar-banana-sports-drink',
  'before', '30-60 min', 30, 60, 'top_up', 'Energy Bar', 'fast', '{gluten}',
  '54kg: 1 bar + 1 banana + 1 cup drink = 69g. 73kg: 1 bar + 1 banana + 2 cups drink = 83g. 91kg: 1 bar + 2 bananas + 2 cups drink = 110g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('energy_bar', 1, 1, 1)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('sports_drink', 1, 1, 2))
  ) AS t(item)),
  'validated', 18
);

-- ---- Template 19: Granola Bar + Banana + OJ ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Granola Bar + Banana + OJ',
  'granola-bar-banana-oj',
  'before', '30-60 min', 30, 60, 'top_up', 'Energy Bar', 'fast', '{gluten}',
  '54kg: 0.75 bar + banana + 0.5 cup OJ (57g); 91kg: 1 bar + banana + 1.5 cups OJ (107g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('energy_bar', 1, 0.75, 1)),
    (public._build_food_item('banana', 1, 1, 1)),
    (public._build_food_item('orange_juice', 1, 0.5, 1.5))
  ) AS t(item)),
  'validated', 19
);

-- ---- Template 20: Energy Gel + Water (version B) ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Energy Gel + Water (version B)',
  'energy-gel-water-b',
  'before', '< 30 min', 0, 30, 'top_up', 'Energy Gel', 'fast', '{}',
  '54kg: 1 gel (27g target); 91kg: 2 gels (50g target)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('energy_gel', 1, 1, 2)),
    (public._build_food_item('water', 1, 1, 1))
  ) AS t(item)),
  'validated', 20
);

-- ---- Template 21: Energy Chews + Water ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Energy Chews + Water',
  'energy-chews-water',
  'before', '< 30 min', 0, 30, 'top_up', 'Energy Chews', 'fast', '{}',
  '54kg: 1 package (24g); 91kg: 2 packages (48g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('energy_chews', 1, 1, 2)),
    (public._build_food_item('water', 1, 1, 1))
  ) AS t(item)),
  'validated', 21
);

-- ---- Template 22: Fig Bars + Banana + Water ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Fig Bars + Banana + Water',
  'fig-bars-banana-water',
  'before', '30-60 min', 30, 60, 'top_up', 'Fig Bars', 'medium', '{gluten}',
  '54kg: 1 fig bar + 1 banana = 65g. 73kg: 1.5 fig bars + 1 banana = 84g. 91kg: 2 fig bars + 2 bananas = 130g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('fig_bar', 1, 1, 2)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('water', 2, 1, 2))
  ) AS t(item)),
  'validated', 22
);

-- ---- Template 23: Fig Bars ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Fig Bars',
  'fig-bars',
  'before', '30-60 min', 30, 60, 'top_up', 'Fig Bars', 'medium', '{gluten}',
  '54kg: 1 bar of twin-pack (19g); 91kg: 1.5 twin-packs (57g) - Higher fat, best for slower runners',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('fig_bar', 1, 0.5, 1.5))
  ) AS t(item)),
  'validated', 23
);

-- ---- Template 24: Waffles + Almond Butter + Banana ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Waffles + Almond Butter + Banana',
  'waffles-almond-butter-banana',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Waffles', 'medium', '{gluten,tree_nuts,eggs,dairy}',
  '54kg: 1.5 waffles + 1 tbsp almond butter + banana + syrup (72g); 91kg: 3 waffles + 2 tbsp almond butter + banana + 2.5 tbsp syrup (116g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('toaster_waffle', 2, 1.5, 3)),
    (public._build_food_item('almond_butter', 2, 1, 2)),
    (public._build_food_item('banana', 1, 1, 1)),
    (public._build_food_item('maple_syrup', 2, 1, 2.5))
  ) AS t(item)),
  'validated', 24
);

-- ---- Template 25: Rice Cakes + PB + Banana + Water ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Rice Cakes + Peanut Butter + Banana + Water',
  'rice-cakes-pb-banana-water',
  'before', '1-2 hours', 60, 120, 'snack', 'Rice Cakes', 'fast', '{peanuts}',
  '54kg: 2 cakes + 1 tbsp PB + 1 banana = 48g. 73kg: 3 cakes + 1.5 tbsp PB + 1.5 bananas = 72g. 91kg: 4 cakes + 2 tbsp PB + 2 bananas = 96g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('rice_cake_plain', 2, 2, 4)),
    (public._build_food_item('peanut_butter', 1, 1, 2)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('water', 2, 2, 2))
  ) AS t(item)),
  'validated', 25
);

-- ---- Template 26: Pancakes + Maple Syrup + Eggs ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Pancakes + Maple Syrup + Eggs',
  'pancakes-maple-syrup-eggs',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Pancakes', 'medium', '{gluten,eggs,dairy}',
  '54kg: 1.5 pancakes + 1.5 tbsp syrup + 1 egg (67g); 91kg: 3 pancakes + 2.5 tbsp syrup + 2 eggs (106g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('pancake_medium', 2, 1.5, 3)),
    (public._build_food_item('maple_syrup', 2, 1.5, 2.5)),
    (public._build_food_item('scrambled_eggs', 2, 1, 2))
  ) AS t(item)),
  'validated', 26
);

-- ---- Template 27: Waffles with Maple Syrup ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Waffles with Maple Syrup',
  'waffles-maple-syrup',
  'before', '1-2 hours', 60, 120, 'snack', 'Waffles', 'medium', '{gluten,eggs,dairy}',
  '54kg: 1.5 waffles + 1.5 tbsp syrup + banana (69g); 91kg: 3 waffles + 2.5 tbsp syrup + banana (107g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('toaster_waffle', 2, 1.5, 3)),
    (public._build_food_item('maple_syrup', 2, 1.5, 2.5)),
    (public._build_food_item('banana', 1, 1, 1))
  ) AS t(item)),
  'validated', 27
);

-- ---- Template 28: Pancakes + Syrup + Banana + OJ ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Pancakes + Syrup + Banana + Orange Juice',
  'pancakes-syrup-banana-oj',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Pancakes', 'medium', '{gluten,eggs,dairy}',
  '54kg: 2 pancakes + 2 tbsp syrup + 1 banana + 1 cup OJ = 105g. 73kg: 3 pancakes + 2 tbsp syrup + 1 banana + 1 cup OJ = 123g. 91kg: 4 pancakes + 3 tbsp syrup + 2 bananas + 1 cup OJ = 168g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('pancake_medium', 2, 2, 4)),
    (public._build_food_item('maple_syrup', 2, 2, 3)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('orange_juice', 1, 1, 1))
  ) AS t(item)),
  'validated', 28
);

-- ---- Template 29: Pasta with Light Sauce + Toast ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Pasta with Light Sauce + Toast',
  'pasta-light-sauce-toast',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Pasta', 'medium', '{gluten}',
  '54kg: 1.5 cups pasta + 1 slice toast + honey (78g); 91kg: 2.5 cups pasta + 2 slices toast + 1.5 tbsp honey (125g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('pasta_cooked', 2, 1.5, 2.5)),
    (public._build_food_item('white_bread', 2, 1, 2)),
    (public._build_food_item('honey', 1, 1, 1.5))
  ) AS t(item)),
  'validated', 29
);

-- ---- Template 30: Rice + Sweet Potato + Eggs ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Rice + Sweet Potato + Eggs',
  'rice-sweet-potato-eggs',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Rice', 'medium', '{eggs}',
  '54kg: 0.75 cup rice + 0.75 sweet potato + 1 egg (70g); 91kg: 1.25 cups rice + sweet potato + 2 eggs (113g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('white_rice_cooked', 1, 0.75, 1.25)),
    (public._build_food_item('sweet_potato', 1, 0.75, 1)),
    (public._build_food_item('scrambled_eggs', 2, 1, 2))
  ) AS t(item)),
  'validated', 30
);

-- ---- Template 31: Rice Cakes + Honey + Berries + Water ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Rice Cakes + Honey + Berries + Water',
  'rice-cakes-honey-berries-water',
  'before', '1-2 hours', 60, 120, 'snack', 'Rice Cakes', 'fast', '{}',
  '54kg: 2 cakes + 1 tbsp honey + 0.5 cup berries = 42g. 73kg: 3 cakes + 1.5 tbsp honey = 52g. 91kg: 4 cakes + 2 tbsp honey = 69g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('rice_cake_plain', 2, 2, 4)),
    (public._build_food_item('honey', 1, 1, 2)),
    (public._build_food_item('mixed_berries', 0.5, 0.5, 1)),
    (public._build_food_item('water', 1, 1, 1))
  ) AS t(item)),
  'validated', 31
);

-- ---- Template 32: Cereal + Milk + Banana + Toast ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Cereal + Milk + Banana + Toast',
  'cereal-milk-banana-toast',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Cereal', 'fast', '{gluten,dairy}',
  '54kg: 1 cup cereal + 1 cup milk + 1 banana + 1 toast = 80g. 73kg: 1.5 cups cereal + 1 cup milk + 1 banana + 1 toast = 92g. 91kg: 2 cups cereal + 1 cup milk + 2 bananas + 2 toasts = 134g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('cereal', 1, 1, 2)),
    (public._build_food_item('milk_whole', 1, 1, 1)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('white_bread', 1, 1, 2))
  ) AS t(item)),
  'validated', 32
);

-- ---- Template 33: Cereal + Milk + Toast + Banana ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Cereal + Milk + Toast + Banana',
  'cereal-milk-toast-banana',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Cereal', 'fast', '{gluten,dairy}',
  '54kg: 1 cup cereal + 0.75 cup milk + 1 slice toast + banana (72g); 91kg: 2 cups cereal + 1 cup milk + 2 slices toast + banana (114g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('cereal', 1.5, 1, 2)),
    (public._build_food_item('milk_whole', 1, 0.75, 1)),
    (public._build_food_item('white_bread', 2, 1, 2)),
    (public._build_food_item('banana', 1, 1, 1))
  ) AS t(item)),
  'validated', 33
);

-- ---- Template 34: Dried Fruit Mix ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Dried Fruit Mix',
  'dried-fruit-mix',
  'before', '1-2 hours', 60, 120, 'snack', 'Dried Fruit', 'fast', '{}',
  '54kg: 1 pair dates only (18g) + water; 91kg: 2 pairs dates + raisins (70g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('dates', 1, 1, 2)),
    (public._build_food_item('raisins', 1, 0, 1))
  ) AS t(item)),
  'validated', 34
);

-- ---- Template 35: Cereal with Milk + Banana ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Cereal with Milk + Banana',
  'cereal-milk-banana',
  'before', '1-2 hours', 60, 120, 'snack', 'Cereal', 'fast', '{gluten,dairy}',
  '54kg: 0.75 cup cereal + 0.75 cup milk + banana (51g); 91kg: 1.5 cups cereal + 1 cup milk + banana (78g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('cereal', 1, 0.75, 1.5)),
    (public._build_food_item('milk_whole', 1, 0.75, 1)),
    (public._build_food_item('banana', 1, 1, 1))
  ) AS t(item)),
  'validated', 35
);

-- ---- Template 36: Applesauce (cup) ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Applesauce (cup)',
  'applesauce-cup',
  'before', '< 30 min', 0, 30, 'top_up', 'Applesauce', 'fast', '{}',
  '54kg: 1 cup (28g); 91kg: 1.5 cups (42g) + add honey for more carbs',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('applesauce_cup', 1, 1, 1.5))
  ) AS t(item)),
  'validated', 36
);

-- ---- Template 37: Graham Crackers + Honey + Banana ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Graham Crackers + Honey + Banana',
  'graham-crackers-honey-banana',
  'before', '30-60 min', 30, 60, 'top_up', 'Graham Crackers', 'fast', '{gluten}',
  '54kg: 3 sheets + 1.5 tbsp honey + banana (64g); 91kg: 5 sheets + 2.5 tbsp honey + banana (102g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('graham_crackers', 2, 1.5, 2.5)),
    (public._build_food_item('honey', 2, 1.5, 2.5)),
    (public._build_food_item('banana', 1, 1, 1))
  ) AS t(item)),
  'validated', 37
);

-- ---- Template 38: Graham Crackers + Banana + Electrolyte Drink ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Graham Crackers + Banana + Electrolyte Drink',
  'graham-crackers-banana-electrolyte',
  'before', '< 30 min', 0, 30, 'top_up', 'Graham Crackers', 'fast', '{gluten}',
  '54kg: 2 sheets + 1 banana = 49g. 73kg: 3 sheets + 1.5 bananas = 74g. 91kg: 4 sheets + 2 bananas = 98g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('graham_crackers', 1, 1, 2)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('electrolyte_drink', 1, 1, 1)),
    (public._build_food_item('water', 2, 2, 2))
  ) AS t(item)),
  'validated', 38
);

-- ---- Template 39: Orange Juice ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Orange Juice',
  'orange-juice',
  'before', '30-60 min', 30, 60, 'top_up', 'Juice', 'fast', '{}',
  '54kg: 1.5 cups (39g); 91kg: 2.5 cups (65g)',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('orange_juice', 2, 1.5, 2.5))
  ) AS t(item)),
  'validated', 39
);

-- ---- Template 40: Sports Drink Only ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Sports Drink Only',
  'sports-drink-only',
  'before', '< 30 min', 0, 30, 'top_up', 'Sports Drink', 'fast', '{}',
  '54kg: 2 cups = 28g. 73kg: 3 cups = 42g. 91kg: 4 cups = 56g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('sports_drink', 2, 2, 4))
  ) AS t(item)),
  'validated', 40
);

-- ---- Template 41: Superhero Muffin + Banana + Coffee ----
INSERT INTO public.templates (name, slug, phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type, base_category, digestion_speed, allergens, notes, foods, validation_status, sort_order)
VALUES (
  'Superhero Muffin + Banana + Coffee',
  'superhero-muffin-banana-coffee',
  'before', '3-4 hours', 180, 240, 'full_meal', 'Muffin', 'medium', '{gluten,eggs}',
  '54kg: 1 muffin + 1 banana = 52g. 73kg: 2 muffins + 1 banana = 77g. 91kg: 2 muffins + 2 bananas = 104g.',
  (SELECT jsonb_agg(item) FROM (VALUES
    (public._build_food_item('superhero_muffin', 1, 1, 2)),
    (public._build_food_item('banana', 1, 1, 2)),
    (public._build_food_item('coffee', 1, 1, 1)),
    (public._build_food_item('water', 1, 1, 1))
  ) AS t(item)),
  'validated', 41
);

-- ============================================================================
-- COMPUTE TOTALS: Update precomputed totals from JSONB foods data
-- ============================================================================

UPDATE public.templates SET
  total_carbs_g = (
    SELECT COALESCE(SUM(
      (item->>'carbs_g')::NUMERIC * (item->>'default_servings')::NUMERIC
    ), 0)
    FROM jsonb_array_elements(foods) AS item
  ),
  total_protein_g = (
    SELECT COALESCE(SUM(
      (item->>'protein_g')::NUMERIC * (item->>'default_servings')::NUMERIC
    ), 0)
    FROM jsonb_array_elements(foods) AS item
  ),
  total_fat_g = (
    SELECT COALESCE(SUM(
      (item->>'fat_g')::NUMERIC * (item->>'default_servings')::NUMERIC
    ), 0)
    FROM jsonb_array_elements(foods) AS item
  ),
  total_sodium_mg = (
    SELECT COALESCE(SUM(
      (item->>'sodium_mg')::NUMERIC * (item->>'default_servings')::NUMERIC
    ), 0)
    FROM jsonb_array_elements(foods) AS item
  ),
  total_fluid_ml = (
    SELECT COALESCE(SUM(
      (item->>'fluid_ml')::NUMERIC * (item->>'default_servings')::NUMERIC
    ), 0)
    FROM jsonb_array_elements(foods) AS item
  ),
  total_calories = (
    SELECT COALESCE(SUM(
      (item->>'calories')::INTEGER * (item->>'default_servings')::NUMERIC
    ), 0)::INTEGER
    FROM jsonb_array_elements(foods) AS item
  );

-- ============================================================================
-- CLEANUP: Drop helper functions (only needed for seeding)
-- ============================================================================

DROP FUNCTION IF EXISTS public._tf_id(TEXT);
DROP FUNCTION IF EXISTS public._build_food_item(TEXT, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS public._slugify(TEXT);
