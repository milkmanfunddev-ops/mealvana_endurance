-- Add 'transition' category to quick-digest template_foods for brick T1/T2 phases
-- Mirrors V1 migration 20260125163000_add_transition_category_to_foods.sql
-- These foods are suitable for quick consumption during brick workout transitions
UPDATE template_foods
SET categories = array_append(categories, 'transition')
WHERE name IN (
  'energy_gel',
  'sports_drink',
  'energy_chews',
  'sports_drink_mix',
  'electrolyte_drink_mix',
  'electrolyte_tablet',
  'pickle_juice_shot',
  'water'
)
AND NOT ('transition' = ANY(categories));
