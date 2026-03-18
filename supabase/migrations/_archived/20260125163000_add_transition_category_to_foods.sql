-- Add 'transition' category to quick-digesting foods suitable for T1/T2
-- These are foods that can be consumed rapidly during brick workout transitions
-- Suitable for triathlon/brick transition zones

UPDATE foods
SET categories = array_append(categories, 'transition')
WHERE name IN (
  'Gels',
  'Sports drink (carb + electrolytes)',
  'Energy chews',
  'Sports drink mix (carb + electrolytes)',
  'Electrolyte drink mix (electrolyte-only)',
  'Electrolyte tablet (electrolyte-only)',
  'Pickle juice shot'
)
AND NOT ('transition' = ANY(categories));
