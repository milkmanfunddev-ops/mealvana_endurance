-- Add "gluten" allergen to all oatmeal-based templates.
-- While pure oats are technically gluten-free, commercially available oatmeal
-- is typically processed in facilities that also process wheat, barley, and rye.
-- Most gluten-sensitive individuals avoid conventional oatmeal, so we mark it
-- as containing gluten for safety.

-- Update all oatmeal templates that don't already have 'gluten' in allergens
UPDATE templates
SET allergens = CASE
  WHEN allergens IS NULL OR allergens = '{}' THEN ARRAY['gluten']::text[]
  WHEN NOT ('gluten' = ANY(allergens)) THEN allergens || ARRAY['gluten']::text[]
  ELSE allergens
END
WHERE base_category = 'Oatmeal';

-- Also update the template_foods entry for oats_dry itself
UPDATE template_foods
SET allergens = CASE
  WHEN allergens IS NULL OR allergens = '{}' THEN ARRAY['gluten']::text[]
  WHEN NOT ('gluten' = ANY(allergens)) THEN allergens || ARRAY['gluten']::text[]
  ELSE allergens
END
WHERE name = 'oats_dry';
