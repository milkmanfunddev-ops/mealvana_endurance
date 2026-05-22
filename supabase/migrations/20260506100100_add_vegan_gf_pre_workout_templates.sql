-- Issue #13: Pre-workout — vegan + gluten-free athletes have insufficient template coverage
--
-- After filtering for vegan + gluten allergy, almost every pre-workout template is
-- eliminated and only Rice Cake variants survive. Rice Cake variants can't hit carb
-- targets for longer time windows. The "Maximum Restriction" athlete in
-- pre-workout-matrix.test.ts gets only 27g carbs (a single banana add-on) when they
-- need 171g for a full meal.
--
-- Fix: add naturally vegan + gluten-free + low-allergen templates that cover the
-- 1.5-3h (meal) and 30-90min (snack) windows. Banana standalone covers all windows.
--
-- All component foods already exist in template_foods (banana, dates, mixed_berries,
-- white_rice_cooked, baked_potato). No new food rows required.

INSERT INTO public.pre_workout_templates (
  name, base_category, time_window, digestion_speed,
  allergens, excluded_diets, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink,
  carbs_per_serving, protein_per_serving, fat_per_serving,
  sodium_mg, fluid_ml, template_type,
  component_food_names, component_quantities
)
SELECT * FROM (VALUES
  -- ── 1.5-3 HOUR MEAL TEMPLATES ──────────────────────────────────────────
  -- Rice + Banana: classic endurance meal, vegan, GF, no major allergens
  -- 1 cup cooked rice (~45g carb) + 1 medium banana (~27g carb) ≈ 72g per serving
  ('Rice + Banana', 'White Rice', '1.5-3 hours', 'Medium',
   '{}'::text[], '{keto,low_carb}'::text[], '1 plate',
   0.5::numeric, 2::numeric, false, false,
   72::numeric, 5::numeric, 0.5::numeric,
   5::numeric, 0::numeric, 'food',
   '{white_rice_cooked,banana}'::text[],
   '{"white_rice_cooked": 1, "banana": 1}'::jsonb),

  -- Potato + Salt: starchy carb with intentional sodium, vegan, GF
  -- 1 medium baked potato (~37g carb) + ~1/4 tsp salt (~575mg sodium) per serving
  ('Potato + Salt', 'Potato', '1.5-3 hours', 'Medium',
   '{}'::text[], '{keto,low_carb}'::text[], '1 medium potato',
   1::numeric, 2::numeric, false, false,
   37::numeric, 2::numeric, 0.5::numeric,
   300::numeric, 0::numeric, 'food',
   '{baked_potato}'::text[],
   '{"baked_potato": 1}'::jsonb),

  -- Fruit Bowl: dense fruit-only meal — banana + dates + mixed berries
  -- 1 banana (27g) + 3 medjool dates (54g) + 1/2 cup mixed berries (~9g) ≈ 90g
  ('Fruit Bowl', 'Fruit Mix', '1.5-3 hours', 'Fast',
   '{}'::text[], '{keto}'::text[], '1 bowl',
   0.5::numeric, 1.5::numeric, false, false,
   90::numeric, 2::numeric, 1::numeric,
   5::numeric, 0::numeric, 'food',
   '{banana,dates,mixed_berries}'::text[],
   '{"banana": 1, "dates": 3, "mixed_berries": 0.5}'::jsonb),

  -- ── 30-90 MIN SNACK TEMPLATES ──────────────────────────────────────────
  -- Dates + Banana: fast-digesting fruit combo, vegan, GF, no allergens
  -- 2 medjool dates (~36g) + 1 medium banana (~27g) ≈ 63g per serving
  ('Dates + Banana', 'Fruit Mix', '30-90 min', 'Fast',
   '{}'::text[], '{keto}'::text[], '1 serving',
   0.5::numeric, 2::numeric, false, false,
   63::numeric, 1.5::numeric, 0.5::numeric,
   5::numeric, 0::numeric, 'food',
   '{dates,banana}'::text[],
   '{"dates": 2, "banana": 1}'::jsonb),

  -- Banana standalone: simplest possible fallback for any phase
  -- 1 medium banana ≈ 27g carb. Spans snack and top-up windows via algorithm.
  ('Banana', 'Fruit', '30-90 min', 'Fast',
   '{}'::text[], '{keto}'::text[], '1 medium banana',
   1::numeric, 3::numeric, false, false,
   27::numeric, 1.3::numeric, 0.4::numeric,
   1::numeric, 0::numeric, 'food',
   '{banana}'::text[],
   '{"banana": 1}'::jsonb)
) AS v(
  name, base_category, time_window, digestion_speed,
  allergens, excluded_diets, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink,
  carbs_per_serving, protein_per_serving, fat_per_serving,
  sodium_mg, fluid_ml, template_type,
  component_food_names, component_quantities
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.pre_workout_templates t WHERE t.name = v.name
);
