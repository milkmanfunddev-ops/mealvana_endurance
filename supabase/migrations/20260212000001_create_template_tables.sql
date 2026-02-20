-- ============================================================================
-- Migration: Create Template System Tables
--
-- Purpose: Pre-workout nutrition template system with denormalized food data
--
-- Tables:
--   1. template_foods - Food ingredient catalog (44 items, USDA nutrition)
--   2. templates - Denormalized templates with embedded JSONB food arrays
--
-- Date: 2026-02-12
-- ============================================================================

-- ============================================================================
-- TABLE 1: template_foods - Food ingredient catalog
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.template_foods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,                              -- 'white_bread'
  display_name TEXT NOT NULL,                      -- 'White Bread'
  serving_size TEXT NOT NULL,                      -- '1 slice'
  serving_weight_g NUMERIC(6,1),                   -- 25.0

  -- Nutrition per serving
  calories INTEGER DEFAULT 0,
  carbs_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  protein_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  fat_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  fiber_g NUMERIC(6,1) DEFAULT 0,
  sodium_mg NUMERIC(6,1) NOT NULL DEFAULT 0,
  fluid_ml NUMERIC(6,1) DEFAULT 0,

  -- Metadata
  allergens TEXT[] DEFAULT '{}',                   -- {'gluten', 'dairy', ...}
  digestion_speed TEXT DEFAULT 'medium'
    CHECK (digestion_speed IN ('fast', 'medium', 'slow')),

  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  CONSTRAINT uq_template_foods_name UNIQUE (name)
);

COMMENT ON TABLE public.template_foods IS 'Food ingredient catalog for nutrition templates. Nutrition data from USDA FoodData Central.';
COMMENT ON COLUMN public.template_foods.name IS 'Machine-readable identifier (e.g., white_bread)';
COMMENT ON COLUMN public.template_foods.allergens IS 'Array of allergen tags: gluten, dairy, eggs, peanuts, tree_nuts';
COMMENT ON COLUMN public.template_foods.digestion_speed IS 'How quickly food digests: fast (simple carbs), medium, slow (high fat/fiber)';

-- ============================================================================
-- TABLE 2: templates - Denormalized templates with JSONB foods
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,                              -- 'Toast + PB + Banana'
  slug TEXT NOT NULL UNIQUE,                       -- 'toast-pb-banana'

  -- Phase & Timing
  phase TEXT NOT NULL DEFAULT 'before'
    CHECK (phase IN ('before', 'during', 'after', 'transition')),
  timing_window TEXT NOT NULL,                     -- '30-60 min', '3-4 hours', '< 30 min'
  timing_min_minutes INTEGER NOT NULL,             -- 30
  timing_max_minutes INTEGER NOT NULL,             -- 90
  meal_type TEXT NOT NULL DEFAULT 'snack'
    CHECK (meal_type IN ('top_up', 'snack', 'full_meal', 'during_fuel',
                          'recovery', 'transition_fuel')),

  -- Categorization
  base_category TEXT NOT NULL,                     -- 'Toast / Bread', 'Bagel', etc.
  digestion_speed TEXT DEFAULT 'medium'
    CHECK (digestion_speed IN ('fast', 'medium', 'slow')),
  allergens TEXT[] DEFAULT '{}',                   -- Union of all food allergens
  notes TEXT,                                      -- From Notion

  -- DENORMALIZED FOODS (JSONB array)
  -- Each item: {food_id, food_name, display_name, serving_size,
  --             default_servings, min_servings, max_servings,
  --             carbs_g, protein_g, fat_g, sodium_mg, fluid_ml}
  foods JSONB NOT NULL DEFAULT '[]'::jsonb,

  -- Precomputed totals (at default_servings)
  total_carbs_g NUMERIC(6,1) DEFAULT 0,
  total_protein_g NUMERIC(6,1) DEFAULT 0,
  total_fat_g NUMERIC(6,1) DEFAULT 0,
  total_sodium_mg NUMERIC(6,1) DEFAULT 0,
  total_fluid_ml NUMERIC(6,1) DEFAULT 0,
  total_calories INTEGER DEFAULT 0,

  -- Status
  validation_status TEXT DEFAULT 'unvalidated'
    CHECK (validation_status IN ('unvalidated', 'validated', 'needs_adjustment', 'failed')),

  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.templates IS 'Pre-workout nutrition templates with denormalized food data in JSONB. Each template is a curated food combination that scales to hit macro targets.';
COMMENT ON COLUMN public.templates.foods IS 'JSONB array of food items with per-serving nutrition and min/max servings for scaling';
COMMENT ON COLUMN public.templates.timing_window IS 'Display label: < 30 min, 30-60 min, 1-2 hours, 3-4 hours';
COMMENT ON COLUMN public.templates.meal_type IS 'Derived from timing: top_up (<1h), snack (1-2.5h), full_meal (2.5h+)';

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_template_foods_name ON public.template_foods (name);
CREATE INDEX IF NOT EXISTS idx_template_foods_active ON public.template_foods (is_active) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_templates_phase ON public.templates (phase);
CREATE INDEX IF NOT EXISTS idx_templates_timing ON public.templates (timing_window);
CREATE INDEX IF NOT EXISTS idx_templates_category ON public.templates (base_category);
CREATE INDEX IF NOT EXISTS idx_templates_active ON public.templates (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_templates_meal_type ON public.templates (meal_type);
CREATE INDEX IF NOT EXISTS idx_templates_slug ON public.templates (slug);

-- ============================================================================
-- UPDATED_AT TRIGGER
-- ============================================================================

-- Reuse existing trigger function if available, otherwise create
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_template_foods_updated_at
  BEFORE UPDATE ON public.template_foods
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_templates_updated_at
  BEFORE UPDATE ON public.templates
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.template_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;

-- Public read access (templates are not user-specific)
CREATE POLICY "template_foods_select_all" ON public.template_foods
  FOR SELECT USING (true);

CREATE POLICY "templates_select_all" ON public.templates
  FOR SELECT USING (true);

-- Service role write access
CREATE POLICY "template_foods_insert_service" ON public.template_foods
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR auth.role() = 'anon'
  );

CREATE POLICY "template_foods_update_service" ON public.template_foods
  FOR UPDATE USING (
    auth.role() = 'service_role' OR auth.role() = 'anon'
  );

CREATE POLICY "template_foods_delete_service" ON public.template_foods
  FOR DELETE USING (
    auth.role() = 'service_role' OR auth.role() = 'anon'
  );

CREATE POLICY "templates_insert_service" ON public.templates
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR auth.role() = 'anon'
  );

CREATE POLICY "templates_update_service" ON public.templates
  FOR UPDATE USING (
    auth.role() = 'service_role' OR auth.role() = 'anon'
  );

CREATE POLICY "templates_delete_service" ON public.templates
  FOR DELETE USING (
    auth.role() = 'service_role' OR auth.role() = 'anon'
  );
