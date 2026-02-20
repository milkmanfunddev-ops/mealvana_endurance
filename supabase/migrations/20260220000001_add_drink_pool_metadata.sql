-- ============================================================================
-- Migration: Add Drink Pool Metadata to template_foods
--
-- Purpose: Tag beverages as drink pool items with phase assignments for the
--          per-phase drink selection algorithm in generate-nutrition-plan-v2.
--
-- Changes:
--   1. ADD is_drink_pool BOOLEAN to template_foods
--   2. ADD drink_pool_phases TEXT[] to template_foods
--   3. UPDATE 8 drink items with phase assignments
--
-- Date: 2026-02-20
-- ============================================================================

-- Add drink pool columns
ALTER TABLE public.template_foods
  ADD COLUMN IF NOT EXISTS is_drink_pool BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS drink_pool_phases TEXT[] DEFAULT '{}';

COMMENT ON COLUMN public.template_foods.is_drink_pool IS 'Whether this food is available in the drink selection pool';
COMMENT ON COLUMN public.template_foods.drink_pool_phases IS 'Which phases this drink can be selected for: meal, snack, top_up';

-- ============================================================================
-- Update drink items with phase assignments
-- ============================================================================

-- Water: available in all sub-phases
UPDATE public.template_foods SET
  is_drink_pool = true,
  drink_pool_phases = '{meal,snack,top_up}'
WHERE name = 'water';

-- Coffee: meal and snack only (not ideal right before activity)
UPDATE public.template_foods SET
  is_drink_pool = true,
  drink_pool_phases = '{meal,snack}'
WHERE name = 'coffee';

-- Orange juice: meal and snack (too much fiber/acid for top_up)
UPDATE public.template_foods SET
  is_drink_pool = true,
  drink_pool_phases = '{meal,snack}'
WHERE name = 'orange_juice';

-- Chocolate milk: meal only (high protein/fat, slow digestion)
UPDATE public.template_foods SET
  is_drink_pool = true,
  drink_pool_phases = '{meal}'
WHERE name = 'chocolate_milk';

-- Whole milk: meal only (high fat, slow digestion)
UPDATE public.template_foods SET
  is_drink_pool = true,
  drink_pool_phases = '{meal}'
WHERE name IN ('milk_whole', 'milk');

-- Fruit smoothie: meal and snack
UPDATE public.template_foods SET
  is_drink_pool = true,
  drink_pool_phases = '{meal,snack}'
WHERE name = 'fruit_smoothie';

-- Sports drink: snack and top_up (fast carbs + electrolytes)
UPDATE public.template_foods SET
  is_drink_pool = true,
  drink_pool_phases = '{snack,top_up}'
WHERE name = 'sports_drink';

-- Electrolyte drink/mix: all sub-phases
UPDATE public.template_foods SET
  is_drink_pool = true,
  drink_pool_phases = '{meal,snack,top_up}'
WHERE name = 'electrolyte_drink';

-- ============================================================================
-- Index for drink pool queries
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_template_foods_drink_pool
  ON public.template_foods (is_drink_pool) WHERE is_drink_pool = true;
