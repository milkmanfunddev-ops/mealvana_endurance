-- Beverage & Fluid Redesign
--
-- Problem: Templates were pairing foods with beverages (e.g., "Granola Bar + Sports Drink"),
-- and the algorithm was counting fluid from non-liquid foods (banana 88ml, grapes 122ml)
-- toward hydration targets, causing fluid totals of 300%+ of target.
--
-- Solution:
-- A. Add is_liquid flag to template_foods table (true for water, coffee, sports_drink, milk, OJ)
-- B. Add has_liquid_base flag to templates (true for smoothie+milk, cereal+milk)
-- C. Fix cereal templates missing milk ingredient (same bug as smoothies)
-- D. Add is_liquid to every food entry in template JSONB (for scaling algorithm)
-- E. Rename templates that paired food with beverages (e.g., "Granola Bar + Sports Drink" → "Granola Bar")
-- F. Deactivate duplicate/bare templates after beverage removal
--
-- Algorithm impact:
-- - Scaling only counts fluid from is_liquid foods (banana fluid no longer inflates totals)
-- - Drink selection skips sub-phases where template has_liquid_base (no water alongside cereal+milk)

-- ================================================================
-- A. Schema changes
-- ================================================================

ALTER TABLE template_foods ADD COLUMN IF NOT EXISTS is_liquid BOOLEAN DEFAULT false;
ALTER TABLE templates ADD COLUMN IF NOT EXISTS has_liquid_base BOOLEAN DEFAULT false;

-- ================================================================
-- B. Set is_liquid on the 5 liquid template_foods
-- ================================================================

UPDATE template_foods
SET is_liquid = true
WHERE name IN ('water', 'coffee', 'sports_drink', 'milk', 'orange_juice');

-- ================================================================
-- C. Fix cereal templates missing milk
-- (Same bug as smoothies fixed in migration 5 — milk is an
-- inherent ingredient of "Cereal + Milk" but was missing from JSONB)
-- ================================================================

UPDATE templates
SET
  foods = foods || '[{
    "food_id": "729254f8-7c67-4814-8d22-c232871d810b",
    "food_name": "milk",
    "display_name": "Milk (whole)",
    "serving_size": "1 cup (8 oz)",
    "carbs_g": 12,
    "protein_g": 8,
    "fat_g": 8,
    "sodium_mg": 105,
    "fluid_ml": 220,
    "calories": 149,
    "allergens": ["dairy"],
    "digestion_speed": "medium",
    "default_servings": 1,
    "min_servings": 0.5,
    "max_servings": 2,
    "is_liquid": true
  }]'::jsonb,
  food_names = array_append(food_names, 'milk'),
  allergens = CASE
    WHEN NOT ('dairy' = ANY(COALESCE(allergens, '{}'::text[])))
      THEN COALESCE(allergens, '{}'::text[]) || ARRAY['dairy']::text[]
    ELSE allergens
  END,
  excluded_diets = (
    SELECT array_agg(DISTINCT d) FROM unnest(
      COALESCE(excluded_diets, '{}'::text[]) || ARRAY['vegan', 'paleo']::text[]
    ) AS d
  ),
  total_carbs_g = total_carbs_g + 12,
  total_protein_g = total_protein_g + 8,
  total_fat_g = total_fat_g + 8,
  total_sodium_mg = total_sodium_mg + 105,
  total_fluid_ml = total_fluid_ml + 220,
  total_calories = total_calories + 149
WHERE name IN (
  'Cereal + Milk',
  'Cereal + Milk + Banana',
  'Cereal + Milk + Berries'
)
AND NOT EXISTS (
  SELECT 1 FROM jsonb_array_elements(foods) AS food
  WHERE food->>'food_name' = 'milk'
);

-- ================================================================
-- D. Add is_liquid flag to ALL template JSONB food entries
-- milk and orange_juice → is_liquid: true
-- everything else → is_liquid: false
-- ================================================================

UPDATE templates
SET foods = (
  SELECT jsonb_agg(
    CASE
      WHEN elem->>'food_name' IN ('milk', 'orange_juice')
      THEN elem || '{"is_liquid": true}'::jsonb
      ELSE elem || '{"is_liquid": false}'::jsonb
    END
  )
  FROM jsonb_array_elements(foods) AS elem
)
WHERE foods IS NOT NULL
  AND jsonb_typeof(foods) = 'array'
  AND jsonb_array_length(foods) > 0;

-- ================================================================
-- E. Set has_liquid_base on templates with inherent liquid
-- (smoothie templates with milk/OJ + cereal templates with milk)
-- These templates already include their liquid — no separate drink needed
-- ================================================================

UPDATE templates
SET has_liquid_base = true
WHERE name IN (
  -- Smoothie templates with milk (6)
  'Smoothie: Banana + PB + Milk',
  'Smoothie: Banana + Milk + Honey',
  'Smoothie: Banana + Dates + Milk',
  'Smoothie: Banana + Berries + Milk',
  'Smoothie: Banana + Protein Powder + Milk',
  'Smoothie: Banana + Oats + Milk + Honey',
  -- Smoothie template with OJ (1)
  'Smoothie: Mango + Banana + OJ',
  -- Cereal templates with milk (3)
  'Cereal + Milk',
  'Cereal + Milk + Banana',
  'Cereal + Milk + Berries'
);

-- ================================================================
-- F. Rename templates — remove beverage from name
-- The drink pool algorithm assigns beverages separately per sub-phase.
-- Templates should be food-only.
-- ================================================================

-- "Coffee + Banana" → "Banana (snack)" — coffee comes from drink pool
UPDATE templates
SET name = 'Banana (snack)',
    slug = 'banana-snack',
    base_category = 'Banana-Anchored'
WHERE name = 'Coffee + Banana';

-- "Coffee + Toast + PB" → "Toast + PB" — coffee comes from drink pool
UPDATE templates
SET name = 'Toast + PB',
    slug = 'toast-pb',
    base_category = 'Toast / Bread'
WHERE name = 'Coffee + Toast + PB';

-- Quick Grab templates: remove "+ Sports Drink" — drink pool provides it
UPDATE templates
SET name = 'Applesauce Pouch',
    slug = 'applesauce-pouch'
WHERE name = 'Applesauce Pouch + Sports Drink';

UPDATE templates
SET name = 'Fig Bars',
    slug = 'fig-bars'
WHERE name = 'Fig Bars + Sports Drink';

UPDATE templates
SET name = 'Granola Bar',
    slug = 'granola-bar'
WHERE name = 'Granola Bar + Sports Drink';

UPDATE templates
SET name = 'Pretzels',
    slug = 'pretzels'
WHERE name = 'Pretzels + Sports Drink';

-- ================================================================
-- G. Deactivate duplicate/bare templates
-- ================================================================

-- "Banana + Sports Drink" and "Sports Drink + Banana" are both just banana top_ups
-- "Banana (alone)" already covers this sub-phase
UPDATE templates
SET is_active = false
WHERE name IN (
  'Banana + Sports Drink',
  'Sports Drink + Banana'
);

-- "OJ + Toast" is just white bread without OJ — too bare, many other toast options exist
UPDATE templates
SET is_active = false
WHERE name = 'OJ + Toast';
