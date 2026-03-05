-- Fix during-solver data issues:
-- 1. Increase electrolyte_tablet max_servings_during from 4 to 8 (long ultras need 6-8)
-- 2. Ensure water has is_essential=true and product_type='beverage' for proper routing
-- 3. Clear serving_unit for all during-phase template foods to prevent display name duplication
--    (display_name_plural already contains the unit where needed)

-- Issue 1: Increase electrolyte cap for long activities
UPDATE template_foods SET max_servings_during = 8, updated_at = now()
WHERE name = 'electrolyte_tablet';

-- Issue 1: Ensure water is marked essential and has product_type for categorizeFood()
UPDATE template_foods SET is_essential = true, updated_at = now()
WHERE name = 'water' AND (is_essential IS NULL OR is_essential = false);

UPDATE template_foods SET product_type = 'beverage', updated_at = now()
WHERE name = 'water' AND product_type IS NULL;

-- Issue 5: Clear serving_unit to prevent duplication with display_name_plural
-- display_name_plural already reads naturally (e.g. "bottles Sports Drink")
-- so _formatQuantity() should use "$qty $displayNamePlural" path
UPDATE template_foods SET serving_unit = NULL, updated_at = now()
WHERE name IN (
  'sports_drink', 'water', 'high_carb_drink_mix',
  'electrolyte_drink_mix', 'energy_gel', 'energy_chews',
  'electrolyte_tablet', 'energy_bar', 'stroopwafel'
);
