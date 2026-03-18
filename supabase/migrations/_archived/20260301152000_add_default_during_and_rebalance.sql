-- ============================================================================
-- Add default_during and rebalance during-phase defaults
-- ============================================================================

BEGIN;

-- Remove prior experimental field if it exists.
ALTER TABLE template_foods
DROP COLUMN IF EXISTS during_priority_bias;

-- Explicit default during-recommendation flag.
ALTER TABLE template_foods
ADD COLUMN IF NOT EXISTS default_during boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN template_foods.default_during IS
  'Whether this food is part of the default during-activity recommendation set.';

-- Ensure Energy Chews exists (some environments are missing this row).
INSERT INTO template_foods (
  name, display_name, display_name_plural, serving_size, serving_weight_g,
  calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml,
  allergens, digestion_speed, product_type,
  categories, activity_types,
  is_liquid, is_drink_pool, drink_pool_phases,
  is_electrolyte, is_essential,
  max_servings_before, max_servings_during, max_servings_after,
  to_exclude_from_solver, show_in_preferences
) VALUES (
  'energy_chews', 'Energy Chews', 'packages Energy Chews', '1 package', 40.0,
  100, 24.0, 0.0, 0.0, 0.0, 108.0, 0.0,
  '{}', 'fast', 'chew',
  '{before_run,during_run}', '{running,cycling,swimming}',
  false, false, '{}',
  false, false,
  2, 6, 0,
  false, true
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
  digestion_speed = EXCLUDED.digestion_speed,
  product_type = EXCLUDED.product_type,
  categories = EXCLUDED.categories,
  activity_types = EXCLUDED.activity_types,
  is_liquid = EXCLUDED.is_liquid,
  max_servings_before = EXCLUDED.max_servings_before,
  max_servings_during = GREATEST(template_foods.max_servings_during, EXCLUDED.max_servings_during),
  max_servings_after = EXCLUDED.max_servings_after,
  to_exclude_from_solver = EXCLUDED.to_exclude_from_solver,
  show_in_preferences = EXCLUDED.show_in_preferences,
  updated_at = now();

-- Core + light expanded during defaults for running.
UPDATE template_foods
SET default_during = true
WHERE name IN (
  'sports_drink',
  'energy_gel',
  'energy_chews',
  'electrolyte_tablet',
  'water',
  'dates',
  'stroopwafel'
);

-- Ensure key defaults are feasible during.
UPDATE template_foods
SET categories = CASE
      WHEN NOT ('during_run' = ANY(categories)) THEN array_append(categories, 'during_run')
      ELSE categories
    END,
    max_servings_during = GREATEST(COALESCE(max_servings_during, 0), 4)
WHERE name = 'energy_gel';

UPDATE template_foods
SET categories = CASE
      WHEN NOT ('during_run' = ANY(categories)) THEN array_append(categories, 'during_run')
      ELSE categories
    END,
    max_servings_during = GREATEST(COALESCE(max_servings_during, 0), 8)
WHERE name IN ('sports_drink', 'water');

UPDATE template_foods
SET categories = CASE
      WHEN NOT ('during_run' = ANY(categories)) THEN array_append(categories, 'during_run')
      ELSE categories
    END,
    max_servings_during = LEAST(GREATEST(COALESCE(max_servings_during, 2), 1), 2)
WHERE name = 'electrolyte_tablet';

-- Keep pickle juice/raisins/applesauce available for running during,
-- but they are not defaults unless explicitly preferred by user.
UPDATE template_foods
SET is_liquid = false,
    max_servings_before = 0,
    max_servings_during = LEAST(GREATEST(COALESCE(max_servings_during, 1), 1), 2),
    max_servings_after = 0
WHERE name = 'pickle_juice_shot';

UPDATE template_foods
SET categories = CASE
      WHEN NOT ('during_run' = ANY(categories)) THEN array_append(categories, 'during_run')
      ELSE categories
    END
WHERE name IN ('pickle_juice_shot', 'raisins', 'applesauce_pouch', 'dates', 'stroopwafel');

-- Ensure indivisible flags if column exists.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'template_foods'
      AND column_name = 'is_indivisible'
  ) THEN
    UPDATE template_foods
    SET is_indivisible = true
    WHERE name IN ('electrolyte_tablet', 'energy_gel', 'pickle_juice_shot');
  END IF;
END $$;

COMMIT;
