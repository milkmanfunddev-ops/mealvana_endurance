-- ============================================================================
-- Migration: Strip Beverages from Template Foods
--
-- Purpose: Remove all beverage items from template JSONB foods arrays.
--          Drinks are now handled by the per-phase drink selection system
--          (drinkSelection.js). Having beverages in template foods causes
--          double-counting when the drink system adds its own drink.
--
-- Beverage food_names to strip:
--   water, coffee, orange_juice, sports_drink, milk, milk_whole,
--   chocolate_milk, fruit_smoothie, electrolyte_drink
--
-- Edge cases:
--   - Templates that would have 0 foods after stripping (pure-beverage
--     templates like "Sports Drink Only") are deactivated (is_active = false)
--   - Totals are recalculated from remaining food items
--
-- Date: 2026-02-13
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Deactivate pure-beverage templates
--
-- These templates have NO non-beverage foods. After stripping, they'd be empty.
-- The drink pool now handles these scenarios directly.
-- ============================================================================

UPDATE public.templates
SET is_active = false
WHERE NOT EXISTS (
  SELECT 1
  FROM jsonb_array_elements(foods) AS item
  WHERE item->>'food_name' NOT IN (
    'water', 'coffee', 'orange_juice', 'sports_drink',
    'milk', 'milk_whole', 'chocolate_milk', 'whole_milk',
    'fruit_smoothie', 'electrolyte_drink'
  )
)
AND foods IS NOT NULL
AND jsonb_array_length(foods) > 0;

-- ============================================================================
-- STEP 2: Strip beverage items from all remaining active templates
-- ============================================================================

UPDATE public.templates
SET foods = sub.filtered_foods
FROM (
  SELECT
    t.id,
    (
      SELECT jsonb_agg(item)
      FROM jsonb_array_elements(t.foods) AS item
      WHERE item->>'food_name' NOT IN (
        'water', 'coffee', 'orange_juice', 'sports_drink',
        'milk', 'milk_whole', 'chocolate_milk', 'whole_milk',
        'fruit_smoothie', 'electrolyte_drink'
      )
    ) AS filtered_foods
  FROM public.templates t
  WHERE t.is_active = true
  AND EXISTS (
    SELECT 1
    FROM jsonb_array_elements(t.foods) AS item
    WHERE item->>'food_name' IN (
      'water', 'coffee', 'orange_juice', 'sports_drink',
      'milk', 'milk_whole', 'chocolate_milk', 'whole_milk',
      'fruit_smoothie', 'electrolyte_drink'
    )
  )
) sub
WHERE templates.id = sub.id
AND sub.filtered_foods IS NOT NULL
AND jsonb_array_length(sub.filtered_foods) > 0;

-- ============================================================================
-- STEP 3: Recalculate totals for ALL active templates
-- ============================================================================

UPDATE public.templates
SET
  total_carbs_g   = sub.carbs,
  total_protein_g = sub.protein,
  total_fat_g     = sub.fat,
  total_sodium_mg = sub.sodium,
  total_fluid_ml  = sub.fluid,
  total_calories  = sub.cals
FROM (
  SELECT
    t.id,
    COALESCE(round(sum((f->>'carbs_g')::numeric   * (f->>'default_servings')::numeric), 1), 0) AS carbs,
    COALESCE(round(sum((f->>'protein_g')::numeric  * (f->>'default_servings')::numeric), 1), 0) AS protein,
    COALESCE(round(sum((f->>'fat_g')::numeric      * (f->>'default_servings')::numeric), 1), 0) AS fat,
    COALESCE(round(sum((f->>'sodium_mg')::numeric  * (f->>'default_servings')::numeric), 1), 0) AS sodium,
    COALESCE(round(sum((f->>'fluid_ml')::numeric   * (f->>'default_servings')::numeric), 1), 0) AS fluid,
    COALESCE(round(sum((f->>'calories')::numeric   * (f->>'default_servings')::numeric)), 0)    AS cals
  FROM public.templates t,
       jsonb_array_elements(t.foods) AS f
  WHERE t.is_active = true
  GROUP BY t.id
) sub
WHERE templates.id = sub.id;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Uncomment to check no active templates contain beverages:
-- SELECT t.slug, t.name, item->>'food_name' AS beverage_food
-- FROM public.templates t, jsonb_array_elements(t.foods) AS item
-- WHERE t.is_active = true
-- AND item->>'food_name' IN (
--   'water', 'coffee', 'orange_juice', 'sports_drink',
--   'milk', 'milk_whole', 'chocolate_milk', 'whole_milk',
--   'fruit_smoothie', 'electrolyte_drink'
-- );

-- Uncomment to see deactivated templates:
-- SELECT slug, name FROM public.templates WHERE is_active = false;

COMMIT;
