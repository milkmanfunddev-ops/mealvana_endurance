-- Fix electrolyte_tablet plural: was "tablets Electrolyte Tablet" → "Electrolyte Tablets"
UPDATE template_foods
SET display_name_plural = 'Electrolyte Tablets', updated_at = now()
WHERE name = 'electrolyte_tablet';

-- Add water to during_run category (was excluded from bulk update in 20260220000007)
UPDATE template_foods
SET categories = array_append(categories, 'during_run'), updated_at = now()
WHERE name = 'water' AND NOT 'during_run' = ANY(categories);
