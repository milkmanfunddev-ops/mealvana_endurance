-- ============================================================================
-- Migration: Widen Template Portion Ranges
--
-- Purpose: Update min_servings and max_servings in template JSONB foods arrays
-- to allow scaling across all athlete personas (54kg-91kg) and timing windows.
--
-- Problem: Original portion ranges were too tight - full meal templates couldn't
-- scale up to 273g carbs (91kg @ 3h), and top-up templates couldn't always
-- scale down to 27g (54kg @ 0.5h).
--
-- Strategy per meal_type:
--   full_meal: max_servings = max(current, default * 3.5), min_servings = min(current, default * 0.5)
--   snack:     max_servings = max(current, default * 2.5), min_servings = min(current, default * 0.5)
--   top_up:    max_servings = max(current, default * 2.0), min_servings = min(current, default * 0.3)
--
-- Non-carb foods (fat/protein sources, water, coffee) get smaller scaling.
-- All servings rounded to nearest 0.25 and clamped to minimum 0.25.
--
-- Date: 2026-02-12
-- ============================================================================

-- Helper: round to nearest 0.25
CREATE OR REPLACE FUNCTION public._round_quarter(val NUMERIC)
RETURNS NUMERIC AS $$
  SELECT GREATEST(0.25, round(val * 4) / 4);
$$ LANGUAGE sql IMMUTABLE;

-- ============================================================================
-- UPDATE: Widen portion ranges for all templates
-- ============================================================================

UPDATE public.templates
SET foods = (
  SELECT jsonb_agg(
    CASE
      -- For carb-contributing foods (carbs_g > 5): widen based on meal_type
      WHEN (item->>'carbs_g')::numeric > 5 THEN
        jsonb_set(
          jsonb_set(
            item,
            '{max_servings}',
            to_jsonb(
              public._round_quarter(
                GREATEST(
                  (item->>'max_servings')::numeric,
                  CASE templates.meal_type
                    WHEN 'full_meal' THEN (item->>'default_servings')::numeric * 3.5
                    WHEN 'snack'     THEN (item->>'default_servings')::numeric * 2.5
                    WHEN 'top_up'    THEN (item->>'default_servings')::numeric * 2.0
                    ELSE (item->>'default_servings')::numeric * 2.0
                  END
                )
              )
            )
          ),
          '{min_servings}',
          to_jsonb(
            public._round_quarter(
              LEAST(
                (item->>'min_servings')::numeric,
                CASE templates.meal_type
                  WHEN 'full_meal' THEN (item->>'default_servings')::numeric * 0.5
                  WHEN 'snack'     THEN (item->>'default_servings')::numeric * 0.5
                  WHEN 'top_up'    THEN (item->>'default_servings')::numeric * 0.25
                  ELSE (item->>'default_servings')::numeric * 0.5
                END
              )
            )
          )
        )
      -- For low-carb foods (condiments, fats, etc.): moderate widening
      WHEN (item->>'carbs_g')::numeric > 0 AND (item->>'carbs_g')::numeric <= 5 THEN
        jsonb_set(
          jsonb_set(
            item,
            '{max_servings}',
            to_jsonb(
              public._round_quarter(
                GREATEST(
                  (item->>'max_servings')::numeric,
                  (item->>'default_servings')::numeric * 2.0
                )
              )
            )
          ),
          '{min_servings}',
          to_jsonb(
            public._round_quarter(
              LEAST(
                (item->>'min_servings')::numeric,
                (item->>'default_servings')::numeric * 0.5
              )
            )
          )
        )
      -- For zero-carb foods (water, coffee, electrolyte base): keep water scalable
      WHEN (item->>'food_name') IN ('water', 'electrolyte_drink') THEN
        jsonb_set(
          jsonb_set(
            item,
            '{max_servings}',
            to_jsonb(
              public._round_quarter(
                GREATEST(
                  (item->>'max_servings')::numeric,
                  (item->>'default_servings')::numeric * 2.0
                )
              )
            )
          ),
          '{min_servings}',
          to_jsonb(
            public._round_quarter(
              LEAST(
                (item->>'min_servings')::numeric,
                (item->>'default_servings')::numeric * 0.5
              )
            )
          )
        )
      -- Everything else (coffee, etc.): leave as-is
      ELSE item
    END
  )
  FROM jsonb_array_elements(templates.foods) AS item
)
WHERE is_active = true;

-- ============================================================================
-- TARGETED FIXES: Snack templates that can't reach 137g (91kg @ 1.5h)
-- ============================================================================

-- Oatmeal + Berries + Water: raise carb foods max to 3.5
UPDATE templates SET foods = (
  SELECT jsonb_agg(
    CASE
      WHEN item->>'food_name' = 'oatmeal_cooked' THEN jsonb_set(item, '{max_servings}', '3.5')
      WHEN item->>'food_name' = 'mixed_berries' THEN jsonb_set(item, '{max_servings}', '3.5')
      ELSE item
    END
  )
  FROM jsonb_array_elements(foods) item
)
WHERE name = 'Oatmeal + Berries + Water';

-- Rice Cakes + PB + Banana + Water: raise rice cakes to 7, banana to 3
UPDATE templates SET foods = (
  SELECT jsonb_agg(
    CASE
      WHEN item->>'food_name' = 'rice_cake_plain' THEN jsonb_set(item, '{max_servings}', '7')
      WHEN item->>'food_name' = 'banana' THEN jsonb_set(item, '{max_servings}', '3')
      ELSE item
    END
  )
  FROM jsonb_array_elements(foods) item
)
WHERE name = 'Rice Cakes + Peanut Butter + Banana + Water';

-- Rice Cakes + Honey + Berries + Water: raise carb items further
UPDATE templates SET foods = (
  SELECT jsonb_agg(
    CASE
      WHEN item->>'food_name' = 'rice_cake_plain' THEN jsonb_set(item, '{max_servings}', '8')
      WHEN item->>'food_name' = 'honey' THEN jsonb_set(item, '{max_servings}', '3.5')
      WHEN item->>'food_name' = 'mixed_berries' THEN jsonb_set(item, '{max_servings}', '2')
      ELSE item
    END
  )
  FROM jsonb_array_elements(foods) item
)
WHERE name = 'Rice Cakes + Honey + Berries + Water';

-- ============================================================================
-- Recompute totals from updated JSONB (totals are at default_servings, unchanged)
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
    round(sum((f->>'carbs_g')::numeric   * (f->>'default_servings')::numeric), 1) AS carbs,
    round(sum((f->>'protein_g')::numeric  * (f->>'default_servings')::numeric), 1) AS protein,
    round(sum((f->>'fat_g')::numeric      * (f->>'default_servings')::numeric), 1) AS fat,
    round(sum((f->>'sodium_mg')::numeric  * (f->>'default_servings')::numeric), 1) AS sodium,
    round(sum((f->>'fluid_ml')::numeric   * (f->>'default_servings')::numeric), 1) AS fluid,
    round(sum((f->>'calories')::numeric   * (f->>'default_servings')::numeric))    AS cals
  FROM public.templates t,
       jsonb_array_elements(t.foods) AS f
  GROUP BY t.id
) sub
WHERE templates.id = sub.id;

-- ============================================================================
-- Cleanup
-- ============================================================================

DROP FUNCTION IF EXISTS public._round_quarter(NUMERIC);
