-- ============================================================================
-- Migration: Add food_names column to templates
--
-- Purpose: Denormalized TEXT[] of food names for faster conflict avoidance
--          queries in the meal chain algorithm. Avoids repeatedly parsing
--          JSONB foods array during template selection.
--
-- Date: 2026-02-20
-- ============================================================================

-- Add food_names column
ALTER TABLE public.templates
  ADD COLUMN IF NOT EXISTS food_names TEXT[] DEFAULT '{}';

COMMENT ON COLUMN public.templates.food_names IS 'Denormalized array of food_name values from JSONB foods for fast conflict avoidance';

-- ============================================================================
-- Populate food_names from existing JSONB foods arrays
-- ============================================================================

UPDATE public.templates
SET food_names = COALESCE(
  (
    SELECT ARRAY(
      SELECT item->>'food_name'
      FROM jsonb_array_elements(foods) AS item
      WHERE item->>'food_name' IS NOT NULL
    )
  ),
  '{}'
);

-- ============================================================================
-- Index for conflict avoidance queries (overlap checks)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_templates_food_names
  ON public.templates USING GIN (food_names);
