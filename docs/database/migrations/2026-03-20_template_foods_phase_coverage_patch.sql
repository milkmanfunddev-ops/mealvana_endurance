-- Nutrition Plan v3 phase coverage patch (runner-realistic revision)
-- Date: 2026-03-20
-- Purpose:
-- 1) Expand existing food phase coverage (especially during/after hydration+sodium)
-- 2) Add realistic runner-used electrolyte/recovery options
-- 3) Keep patch idempotent via ON CONFLICT(name)

BEGIN;

-- ============================================================================
-- 0) Safety cleanup: disable older experimental items if they exist
-- ============================================================================
UPDATE public.template_foods
SET is_active = false, updated_at = now()
WHERE name IN ('oral_rehydration_solution', 'salty_broth', 'salted_rice_ball', 'sodium_capsule');

-- ============================================================================
-- 1) Patch existing foods for phase coverage and realistic hydration behavior
-- ============================================================================

-- Water: allow after-run recovery hydration and higher during limits for long/hot sessions.
UPDATE public.template_foods
SET
  categories = (
    SELECT COALESCE(array_agg(DISTINCT c), '{}'::text[])
    FROM unnest(coalesce(template_foods.categories, '{}'::text[]) || ARRAY['during_bike','during_swim','after_run']::text[]) AS t(c)
  ),
  max_servings_during = GREATEST(coalesce(max_servings_during, 0), 14),
  max_servings_after = GREATEST(coalesce(max_servings_after, 0), 10),
  updated_at = now()
WHERE name = 'water';

-- Sports drink: make available in bike/swim-specific during categories and after-run.
UPDATE public.template_foods
SET
  categories = (
    SELECT COALESCE(array_agg(DISTINCT c), '{}'::text[])
    FROM unnest(coalesce(template_foods.categories, '{}'::text[]) || ARRAY['during_bike','during_swim','after_run']::text[]) AS t(c)
  ),
  max_servings_during = GREATEST(coalesce(max_servings_during, 0), 12),
  max_servings_after = GREATEST(coalesce(max_servings_after, 0), 6),
  updated_at = now()
WHERE name = 'sports_drink';

-- Electrolyte tablet: model real-world mixing volume (16-20 oz) and expand phase coverage.
UPDATE public.template_foods
SET
  categories = (
    SELECT COALESCE(array_agg(DISTINCT c), '{}'::text[])
    FROM unnest(coalesce(template_foods.categories, '{}'::text[]) || ARRAY['during_bike','during_swim','after_run']::text[]) AS t(c)
  ),
  fluid_ml = GREATEST(coalesce(fluid_ml, 0), 475),
  max_servings_during = GREATEST(coalesce(max_servings_during, 0), 12),
  max_servings_after = GREATEST(coalesce(max_servings_after, 0), 6),
  updated_at = now()
WHERE name = 'electrolyte_tablet';

-- Electrolyte drink mix: include mixed fluid and expand phase coverage.
UPDATE public.template_foods
SET
  categories = (
    SELECT COALESCE(array_agg(DISTINCT c), '{}'::text[])
    FROM unnest(coalesce(template_foods.categories, '{}'::text[]) || ARRAY['during_bike','during_swim','after_run']::text[]) AS t(c)
  ),
  fluid_ml = GREATEST(coalesce(fluid_ml, 0), 500),
  max_servings_during = GREATEST(coalesce(max_servings_during, 0), 6),
  max_servings_after = GREATEST(coalesce(max_servings_after, 0), 3),
  updated_at = now()
WHERE name = 'electrolyte_drink_mix';

-- Pickle juice: keep available, but not default. It's niche, but some runners still use it.
UPDATE public.template_foods
SET
  categories = (
    SELECT COALESCE(array_agg(DISTINCT c), '{}'::text[])
    FROM unnest(coalesce(template_foods.categories, '{}'::text[]) || ARRAY['during_bike','during_swim','after_run']::text[]) AS t(c)
  ),
  max_servings_during = GREATEST(coalesce(max_servings_during, 0), 3),
  max_servings_after = GREATEST(coalesce(max_servings_after, 0), 1),
  default_during = false,
  updated_at = now()
WHERE name = 'pickle_juice_shot';

-- High-carb mix: expose to bike/swim and transition for long fueling cases.
UPDATE public.template_foods
SET
  categories = (
    SELECT COALESCE(array_agg(DISTINCT c), '{}'::text[])
    FROM unnest(coalesce(template_foods.categories, '{}'::text[]) || ARRAY['during_bike','during_swim','transition']::text[]) AS t(c)
  ),
  max_servings_during = GREATEST(coalesce(max_servings_during, 0), 10),
  updated_at = now()
WHERE name = 'high_carb_drink_mix';

-- Pretzels are common aid-station sodium+carb food; make available after-run too.
UPDATE public.template_foods
SET
  categories = (
    SELECT COALESCE(array_agg(DISTINCT c), '{}'::text[])
    FROM unnest(coalesce(template_foods.categories, '{}'::text[]) || ARRAY['after_run']::text[]) AS t(c)
  ),
  max_servings_after = GREATEST(coalesce(max_servings_after, 0), 4),
  updated_at = now()
WHERE name = 'pretzels';

-- Protein shake: allow slightly higher after-run servings for higher protein targets.
UPDATE public.template_foods
SET
  max_servings_after = GREATEST(coalesce(max_servings_after, 0), 3),
  updated_at = now()
WHERE name = 'protein_shake';

-- ============================================================================
-- 2) Add realistic runner-used electrolyte/recovery options
-- ============================================================================

INSERT INTO public.template_foods (
  name,
  display_name,
  serving_size,
  serving_weight_g,
  calories,
  carbs_g,
  protein_g,
  fat_g,
  fiber_g,
  sodium_mg,
  fluid_ml,
  allergens,
  digestion_speed,
  is_active,
  excluded_diets,
  product_type,
  activity_types,
  categories,
  show_in_preferences,
  is_essential,
  is_electrolyte,
  requires_preparation,
  caffeine_mg,
  potassium_mg,
  is_drink_pool,
  drink_pool_phases,
  is_liquid,
  max_servings_before,
  max_servings_during,
  max_servings_after,
  to_exclude_from_solver,
  display_name_plural,
  description,
  serving_amount,
  serving_unit,
  serving_qualifier,
  is_indivisible,
  default_during,
  min_servings_during
)
VALUES
  (
    'high_sodium_electrolyte_mix',
    'High-Sodium Electrolyte Mix',
    '1 stick (mix in 16 oz water)',
    6.0,
    0,
    0.0,
    0.0,
    0.0,
    0.0,
    1000.0,
    480.0,
    '{}'::text[],
    'fast',
    true,
    '{}'::text[],
    'supplement',
    '{running,cycling,swimming}'::text[],
    '{during_run,during_bike,during_swim,transition,after_run}'::text[],
    true,
    false,
    true,
    false,
    0.0,
    200.0,
    false,
    '{}'::text[],
    false,
    0,
    4,
    2,
    false,
    'sticks High-Sodium Electrolyte Mix',
    'Electrolyte mix packet with high sodium for heavy/salty sweaters.',
    1,
    NULL,
    NULL,
    true,
    true,
    1.0
  ),
  (
    'rapid_rehydration_drink',
    'Rapid Rehydration Drink',
    '1 bottle (20 oz)',
    591.0,
    50,
    14.0,
    0.0,
    0.0,
    0.0,
    490.0,
    591.0,
    '{}'::text[],
    'fast',
    true,
    '{}'::text[],
    'sports_drink',
    '{running,cycling,swimming}'::text[],
    '{during_run,during_bike,during_swim,transition,after_run}'::text[],
    true,
    false,
    true,
    false,
    0.0,
    350.0,
    true,
    '{snack,top_up}'::text[],
    true,
    0,
    8,
    4,
    false,
    'bottles Rapid Rehydration Drink',
    'Higher-electrolyte sports drink commonly used in endurance training/racing.',
    1,
    NULL,
    NULL,
    false,
    true,
    0.5
  ),
  (
    'electrolyte_capsule',
    'Electrolyte Capsule',
    '1 capsule',
    1.0,
    0,
    0.0,
    0.0,
    0.0,
    0.0,
    190.0,
    0.0,
    '{}'::text[],
    'fast',
    true,
    '{}'::text[],
    'supplement',
    '{running,cycling,swimming}'::text[],
    '{during_run,during_bike,during_swim,transition,after_run}'::text[],
    true,
    false,
    true,
    false,
    0.0,
    50.0,
    false,
    '{}'::text[],
    false,
    0,
    20,
    8,
    false,
    'Electrolyte Capsules',
    'Swallowable electrolyte capsule used by endurance runners when sodium targets are high.',
    1,
    NULL,
    NULL,
    true,
    true,
    1.0
  ),
  (
    'chocolate_milk',
    'Chocolate Milk',
    '1 cup (8 oz)',
    240.0,
    190,
    30.0,
    9.0,
    5.0,
    1.0,
    160.0,
    240.0,
    '{dairy}'::text[],
    'medium',
    true,
    '{vegan,paleo}'::text[],
    'beverage',
    '{running,cycling,swimming}'::text[],
    '{after_run,before_run}'::text[],
    true,
    false,
    false,
    false,
    0.0,
    420.0,
    true,
    '{meal,snack}'::text[],
    true,
    1,
    0,
    3,
    false,
    'cups Chocolate Milk',
    'Common post-run recovery beverage with carbs, protein, sodium, and fluid.',
    1,
    NULL,
    NULL,
    false,
    false,
    1.0
  ),
  (
    'plant_protein_shake',
    'Plant Protein Shake (RTD)',
    '1 bottle (11 oz)',
    330.0,
    180,
    10.0,
    20.0,
    6.0,
    3.0,
    320.0,
    330.0,
    '{}'::text[],
    'medium',
    true,
    '{paleo}'::text[],
    'beverage',
    '{running,cycling,swimming}'::text[],
    '{after_run}'::text[],
    true,
    false,
    false,
    false,
    0.0,
    350.0,
    true,
    '{meal,snack}'::text[],
    true,
    0,
    0,
    3,
    false,
    'bottles Plant Protein Shake',
    'Dairy-free recovery shake with meaningful protein, sodium, and fluid.',
    1,
    NULL,
    NULL,
    false,
    false,
    1.0
  )
ON CONFLICT (name)
DO UPDATE SET
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
  is_active = EXCLUDED.is_active,
  excluded_diets = EXCLUDED.excluded_diets,
  product_type = EXCLUDED.product_type,
  activity_types = (
    SELECT COALESCE(array_agg(DISTINCT a), '{}'::text[])
    FROM unnest(coalesce(public.template_foods.activity_types, '{}'::text[]) || EXCLUDED.activity_types) AS u(a)
  ),
  categories = (
    SELECT COALESCE(array_agg(DISTINCT c), '{}'::text[])
    FROM unnest(coalesce(public.template_foods.categories, '{}'::text[]) || EXCLUDED.categories) AS u(c)
  ),
  show_in_preferences = EXCLUDED.show_in_preferences,
  is_essential = EXCLUDED.is_essential,
  is_electrolyte = EXCLUDED.is_electrolyte,
  requires_preparation = EXCLUDED.requires_preparation,
  caffeine_mg = EXCLUDED.caffeine_mg,
  potassium_mg = EXCLUDED.potassium_mg,
  is_drink_pool = EXCLUDED.is_drink_pool,
  drink_pool_phases = (
    SELECT COALESCE(array_agg(DISTINCT p), '{}'::text[])
    FROM unnest(coalesce(public.template_foods.drink_pool_phases, '{}'::text[]) || EXCLUDED.drink_pool_phases) AS u(p)
  ),
  is_liquid = EXCLUDED.is_liquid,
  max_servings_before = GREATEST(coalesce(public.template_foods.max_servings_before, 0), EXCLUDED.max_servings_before),
  max_servings_during = GREATEST(coalesce(public.template_foods.max_servings_during, 0), EXCLUDED.max_servings_during),
  max_servings_after = GREATEST(coalesce(public.template_foods.max_servings_after, 0), EXCLUDED.max_servings_after),
  to_exclude_from_solver = EXCLUDED.to_exclude_from_solver,
  display_name_plural = EXCLUDED.display_name_plural,
  description = EXCLUDED.description,
  serving_amount = EXCLUDED.serving_amount,
  serving_unit = EXCLUDED.serving_unit,
  serving_qualifier = EXCLUDED.serving_qualifier,
  is_indivisible = EXCLUDED.is_indivisible,
  default_during = (public.template_foods.default_during OR EXCLUDED.default_during),
  min_servings_during = EXCLUDED.min_servings_during,
  updated_at = now();

-- ==========================================================================
-- 3) Optional verification query
-- ==========================================================================
-- SELECT name, categories, carbs_g, protein_g, sodium_mg, fluid_ml,
--        max_servings_during, max_servings_after, default_during, is_active
-- FROM public.template_foods
-- WHERE name IN (
--   'water','sports_drink','electrolyte_tablet','electrolyte_drink_mix','pickle_juice_shot','high_carb_drink_mix','pretzels',
--   'high_sodium_electrolyte_mix','rapid_rehydration_drink','electrolyte_capsule','chocolate_milk','plant_protein_shake',
--   'oral_rehydration_solution','salty_broth','salted_rice_ball','sodium_capsule'
-- )
-- ORDER BY name;

COMMIT;
