-- Diet filtering fixes, protein cap, and electrolyte improvements
-- Date: 2026-03-20
-- Purpose:
-- 1) Add excluded_diets column to pre_workout_templates for proper vegan/paleo/etc filtering
-- 2) Populate excluded_diets from component foods' data
-- 3) Add gluten_free to oatmeal's excluded_diets in template_foods
-- 4) Cap protein shake max_servings_after to prevent protein overshoot
-- 5) Cap electrolyte capsule max_servings_during and add electrolyte_packet (Liquid IV style)

BEGIN;

-- ============================================================================
-- 1) Add excluded_diets column to pre_workout_templates
-- ============================================================================
ALTER TABLE pre_workout_templates
  ADD COLUMN IF NOT EXISTS excluded_diets text[] DEFAULT '{}'::text[];

COMMENT ON COLUMN pre_workout_templates.excluded_diets IS
  'Diets to exclude this template for, derived from component foods. E.g. {vegan,paleo}';

-- ============================================================================
-- 2) Populate excluded_diets from component template_foods
--    Each pre_workout_template inherits the UNION of its component foods' excluded_diets
-- ============================================================================
UPDATE pre_workout_templates pwt
SET excluded_diets = sub.merged_diets
FROM (
  SELECT pwt2.id,
    ARRAY(
      SELECT DISTINCT UNNEST(tf.excluded_diets)
      FROM UNNEST(pwt2.component_food_names) AS cfn(name)
      JOIN template_foods tf ON tf.name = cfn.name
      WHERE tf.excluded_diets IS NOT NULL
        AND ARRAY_LENGTH(tf.excluded_diets, 1) > 0
    ) AS merged_diets
  FROM pre_workout_templates pwt2
  WHERE ARRAY_LENGTH(pwt2.component_food_names, 1) > 0
) sub
WHERE pwt.id = sub.id;

-- ============================================================================
-- 3) Fix oatmeal: add gluten_free to excluded_diets
--    Oatmeal has allergens={gluten} but excluded_diets only had {keto,low_carb}
-- ============================================================================
UPDATE template_foods
SET excluded_diets = ARRAY_APPEND(excluded_diets, 'gluten_free'),
    updated_at = NOW()
WHERE name = 'oatmeal'
  AND NOT ('gluten_free' = ANY(excluded_diets));

-- Also add gluten_free to any other gluten-containing foods missing it
UPDATE template_foods
SET excluded_diets = ARRAY_APPEND(excluded_diets, 'gluten_free'),
    updated_at = NOW()
WHERE 'gluten' = ANY(allergens)
  AND NOT ('gluten_free' = ANY(excluded_diets));

-- Re-run the pre_workout_templates population to pick up the gluten_free additions
UPDATE pre_workout_templates pwt
SET excluded_diets = sub.merged_diets
FROM (
  SELECT pwt2.id,
    ARRAY(
      SELECT DISTINCT UNNEST(tf.excluded_diets)
      FROM UNNEST(pwt2.component_food_names) AS cfn(name)
      JOIN template_foods tf ON tf.name = cfn.name
      WHERE tf.excluded_diets IS NOT NULL
        AND ARRAY_LENGTH(tf.excluded_diets, 1) > 0
    ) AS merged_diets
  FROM pre_workout_templates pwt2
  WHERE ARRAY_LENGTH(pwt2.component_food_names, 1) > 0
) sub
WHERE pwt.id = sub.id;

-- ============================================================================
-- 4) Cap protein shake max_servings_after to prevent protein overshoot
--    Protein Shake (RTD) = 25g protein/serving → 1 serving max keeps it under control
-- ============================================================================
UPDATE template_foods
SET max_servings_after = 1,
    updated_at = NOW()
WHERE name = 'protein_shake';

UPDATE template_foods
SET max_servings_after = 1,
    updated_at = NOW()
WHERE name = 'plant_protein_shake';

-- ============================================================================
-- 5) Electrolyte improvements
-- ============================================================================

-- 5a) Cap electrolyte capsules at 8 during to push solver toward higher-sodium options
UPDATE template_foods
SET max_servings_during = 8,
    updated_at = NOW()
WHERE name = 'electrolyte_capsule';

-- 5b) Add electrolyte packet (Liquid IV style) - high sodium, easy to carry
INSERT INTO template_foods (
  id, name, display_name, serving_size, serving_weight_g,
  calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml,
  allergens, digestion_speed, is_active, excluded_diets,
  product_type, activity_types, categories,
  show_in_preferences, is_essential, is_electrolyte, requires_preparation,
  caffeine_mg, potassium_mg, is_drink_pool, drink_pool_phases, is_liquid,
  max_servings_before, max_servings_during, max_servings_after,
  to_exclude_from_solver, display_name_plural, description,
  serving_amount, is_indivisible, default_during, min_servings_during
) VALUES (
  gen_random_uuid(), 'electrolyte_packet', 'Electrolyte Packet', '1 packet (in 16 oz water)', 15.0,
  40, 11.0, 0.0, 0.0, 0.0, 510.0, 480.0,
  '{}', 'fast', true, '{}',
  'supplement', '{running,cycling,swimming}', '{during_run,during_bike,during_swim,transition,after_run}',
  true, false, true, false,
  0.0, 370.0, false, '{}', false,
  0, 6, 3,
  false, 'Electrolyte Packets', 'Electrolyte drink packet (like Liquid IV) with ~500mg sodium. Mix in 16oz water.',
  1, true, true, 0.5
) ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  serving_size = EXCLUDED.serving_size,
  serving_weight_g = EXCLUDED.serving_weight_g,
  calories = EXCLUDED.calories,
  carbs_g = EXCLUDED.carbs_g,
  protein_g = EXCLUDED.protein_g,
  fat_g = EXCLUDED.fat_g,
  sodium_mg = EXCLUDED.sodium_mg,
  fluid_ml = EXCLUDED.fluid_ml,
  is_electrolyte = EXCLUDED.is_electrolyte,
  categories = EXCLUDED.categories,
  max_servings_during = EXCLUDED.max_servings_during,
  max_servings_after = EXCLUDED.max_servings_after,
  display_name_plural = EXCLUDED.display_name_plural,
  description = EXCLUDED.description,
  is_indivisible = EXCLUDED.is_indivisible,
  default_during = EXCLUDED.default_during,
  min_servings_during = EXCLUDED.min_servings_during,
  updated_at = NOW();

COMMIT;
