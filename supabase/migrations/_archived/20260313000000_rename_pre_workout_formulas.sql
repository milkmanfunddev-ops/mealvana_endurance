-- Migration: Rename pre_workout_formulas → pre_workout_templates
-- Add fluid_ml and template_type columns for drink/electrolyte support
-- Seed 3 drink items and 2 electrolyte items
-- Idempotent: handles both fresh (table is pre_workout_formulas) and
-- already-renamed (table is pre_workout_templates) states.

-- ============================================================================
-- 1. Rename table (only if old name still exists)
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pre_workout_formulas') THEN
    ALTER TABLE public.pre_workout_formulas RENAME TO pre_workout_templates;
  END IF;
END $$;

-- ============================================================================
-- 2. Add new columns
-- ============================================================================

ALTER TABLE public.pre_workout_templates
  ADD COLUMN IF NOT EXISTS fluid_ml NUMERIC DEFAULT 0 NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'pre_workout_templates' AND column_name = 'template_type'
  ) THEN
    ALTER TABLE public.pre_workout_templates
      ADD COLUMN template_type TEXT DEFAULT 'food' NOT NULL
      CHECK (template_type IN ('food', 'drink', 'electrolyte'));
  END IF;
END $$;

-- ============================================================================
-- 3. Fix min_servings constraint for drinks (0.5 servings allowed)
-- ============================================================================

ALTER TABLE public.pre_workout_templates
  DROP CONSTRAINT IF EXISTS pre_workout_formulas_min_servings_check;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_schema = 'public' AND table_name = 'pre_workout_templates'
    AND constraint_name = 'pre_workout_templates_min_servings_check'
  ) THEN
    ALTER TABLE public.pre_workout_templates
      ADD CONSTRAINT pre_workout_templates_min_servings_check
      CHECK (min_servings >= 0.5);
  END IF;
END $$;

-- ============================================================================
-- 4. Rename indexes (only if old names still exist)
-- ============================================================================

ALTER INDEX IF EXISTS idx_pre_workout_formulas_time_window RENAME TO idx_pre_workout_templates_time_window;
ALTER INDEX IF EXISTS idx_pre_workout_formulas_base_category RENAME TO idx_pre_workout_templates_base_category;
ALTER INDEX IF EXISTS idx_pre_workout_formulas_allergens RENAME TO idx_pre_workout_templates_allergens;

-- ============================================================================
-- 5. Seed drink and electrolyte items (skip if already seeded)
-- ============================================================================

INSERT INTO public.pre_workout_templates
  (name, base_category, time_window, digestion_speed, allergens, serving_unit,
   min_servings, max_servings, plus_banana, plus_sports_drink,
   carbs_per_serving, protein_per_serving, fat_per_serving, sodium_mg, fluid_ml, template_type)
SELECT * FROM (VALUES
  -- DRINKS (hydration, may have sodium)
  ('Water', 'Hydration', '< 30 min', 'Fast', '{}'::text[], '1 cup (8 oz)',
   0.5::numeric, 3::numeric, false, false, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 240::numeric, 'drink'),
  ('Coconut Water', 'Hydration', '< 30 min', 'Fast', '{}'::text[], '1 cup (8 oz)',
   0.5, 2, false, false, 9, 0, 0, 252, 240, 'drink'),
  ('Sports Drink', 'Hydration', '< 30 min', 'Fast', '{}'::text[], '1 cup (8 oz)',
   0.5, 2, false, false, 14, 0, 0, 110, 237, 'drink'),

  -- ELECTROLYTES (sodium, no independent fluid — dissolves in water)
  ('Electrolyte Tablet', 'Electrolyte', '< 30 min', 'Fast', '{}'::text[], '1 tablet',
   1, 2, false, false, 2, 0, 0, 300, 0, 'electrolyte'),
  ('Electrolyte Drink Mix', 'Electrolyte', '< 30 min', 'Fast', '{}'::text[], '1 scoop',
   1, 1, false, false, 15, 0, 0, 400, 0, 'electrolyte')
) AS v(name, base_category, time_window, digestion_speed, allergens, serving_unit,
       min_servings, max_servings, plus_banana, plus_sports_drink,
       carbs_per_serving, protein_per_serving, fat_per_serving, sodium_mg, fluid_ml, template_type)
WHERE NOT EXISTS (
  SELECT 1 FROM public.pre_workout_templates WHERE template_type IN ('drink', 'electrolyte')
);
