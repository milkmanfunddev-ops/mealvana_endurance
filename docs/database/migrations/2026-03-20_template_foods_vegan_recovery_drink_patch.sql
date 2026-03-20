-- Vegan recovery drink patch
-- Date: 2026-03-20
-- Purpose:
-- 1) Remove non-vegan generic recovery drink if present
-- 2) Add one high-protein vegan post-workout recovery drink

BEGIN;

-- If a non-vegan recovery drink was added earlier, disable it.
UPDATE public.template_foods
SET is_active = false, updated_at = now()
WHERE name IN ('recovery_protein_drink');

-- Add/update one vegan plant-based recovery drink option.
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
VALUES (
  'vegan_recovery_protein_drink',
  'Vegan Recovery Protein Drink',
  '1 bottle (14 fl oz)',
  414.0,
  210,
  18.0,
  30.0,
  6.0,
  5.0,
  320.0,
  414.0,
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
  650.0,
  true,
  '{meal,snack}'::text[],
  true,
  0,
  0,
  3,
  false,
  'bottles Vegan Recovery Protein Drink',
  'Plant-based post-workout recovery drink with high protein plus fluid and sodium.',
  1,
  NULL,
  NULL,
  true,
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

-- Optional verification
-- SELECT name, is_active, categories, carbs_g, protein_g, sodium_mg, fluid_ml
-- FROM public.template_foods
-- WHERE name IN ('recovery_protein_drink','vegan_recovery_protein_drink')
-- ORDER BY name;

COMMIT;
