-- ============================================================================
-- STEP 1B: SCHEMA DDL (tables, columns, indexes, triggers, grants)
-- ============================================================================
-- Run on: PRODUCTION Supabase SQL Editor
-- Run AFTER: 01a_enum_fix.sql
-- Safe to re-run (idempotent).
-- ============================================================================

BEGIN;

-- ============================================================================
-- USERS TABLE: 5 missing columns
-- ============================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS unit_system TEXT DEFAULT 'imperial';

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS default_running_pace_min_per_mile REAL DEFAULT NULL;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS default_cycling_speed_mph REAL DEFAULT NULL;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS default_swimming_pace_per_100_sec INTEGER DEFAULT NULL;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nutrition_target_overrides JSONB DEFAULT NULL;

COMMENT ON COLUMN public.users.unit_system IS 'Unit system preference: imperial or metric';
COMMENT ON COLUMN public.users.default_running_pace_min_per_mile IS 'User default running pace in minutes per mile.';
COMMENT ON COLUMN public.users.default_cycling_speed_mph IS 'User default cycling speed in miles per hour.';
COMMENT ON COLUMN public.users.default_swimming_pace_per_100_sec IS 'User default swimming pace in seconds per 100 yards/meters.';
COMMENT ON COLUMN public.users.nutrition_target_overrides IS 'User-configured nutrition target overrides. JSON with pre/during/post activity macro targets.';

-- ============================================================================
-- CREATE template_foods TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.template_foods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  serving_size TEXT NOT NULL,
  serving_weight_g NUMERIC(6,1),

  calories INTEGER DEFAULT 0,
  carbs_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  protein_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  fat_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  fiber_g NUMERIC(6,1) DEFAULT 0,
  sodium_mg NUMERIC(6,1) NOT NULL DEFAULT 0,
  fluid_ml NUMERIC(6,1) DEFAULT 0,

  allergens TEXT[] DEFAULT '{}',
  digestion_speed TEXT DEFAULT 'medium'
    CHECK (digestion_speed IN ('fast', 'medium', 'slow')),

  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  excluded_diets TEXT[] DEFAULT '{}',
  product_type TEXT DEFAULT 'real_food',
  activity_types TEXT[] DEFAULT '{running,cycling,swimming}',
  categories TEXT[] DEFAULT '{before_run}',
  show_in_preferences BOOLEAN DEFAULT true,
  is_essential BOOLEAN DEFAULT false,
  is_electrolyte BOOLEAN DEFAULT false,
  requires_preparation BOOLEAN DEFAULT false,
  caffeine_mg NUMERIC(6,1) DEFAULT 0,
  potassium_mg NUMERIC(6,1) DEFAULT 0,

  is_drink_pool BOOLEAN DEFAULT false,
  drink_pool_phases TEXT[] DEFAULT '{}',
  is_liquid BOOLEAN DEFAULT false,

  max_servings_before INTEGER DEFAULT 4,
  max_servings_during INTEGER DEFAULT 4,
  max_servings_after INTEGER DEFAULT 4,
  to_exclude_from_solver BOOLEAN DEFAULT false,
  display_name_plural TEXT,
  image_address TEXT,
  description TEXT,
  serving_amount REAL,
  serving_unit TEXT,
  serving_qualifier TEXT,

  is_indivisible BOOLEAN DEFAULT false,
  default_during BOOLEAN NOT NULL DEFAULT false,
  min_servings_during NUMERIC(4,1) DEFAULT 1.0,

  CONSTRAINT uq_template_foods_name UNIQUE (name)
);

COMMENT ON TABLE public.template_foods IS 'Food ingredient catalog for nutrition templates.';

-- ============================================================================
-- CREATE templates TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,

  phase TEXT NOT NULL DEFAULT 'before'
    CHECK (phase IN ('before', 'during', 'after', 'transition')),
  timing_window TEXT NOT NULL,
  timing_min_minutes INTEGER NOT NULL,
  timing_max_minutes INTEGER NOT NULL,
  meal_type TEXT NOT NULL DEFAULT 'snack'
    CHECK (meal_type IN ('top_up', 'snack', 'full_meal', 'during_fuel',
                          'recovery', 'transition_fuel')),

  base_category TEXT NOT NULL,
  digestion_speed TEXT DEFAULT 'medium'
    CHECK (digestion_speed IN ('fast', 'medium', 'slow')),
  allergens TEXT[] DEFAULT '{}',
  notes TEXT,

  foods JSONB NOT NULL DEFAULT '[]'::jsonb,

  total_carbs_g NUMERIC(6,1) DEFAULT 0,
  total_protein_g NUMERIC(6,1) DEFAULT 0,
  total_fat_g NUMERIC(6,1) DEFAULT 0,
  total_sodium_mg NUMERIC(6,1) DEFAULT 0,
  total_fluid_ml NUMERIC(6,1) DEFAULT 0,
  total_calories INTEGER DEFAULT 0,

  validation_status TEXT DEFAULT 'unvalidated'
    CHECK (validation_status IN ('unvalidated', 'validated', 'needs_adjustment', 'failed')),

  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  excluded_diets TEXT[] DEFAULT '{}',
  has_liquid_base BOOLEAN DEFAULT false,
  food_names TEXT[] DEFAULT '{}'
);

COMMENT ON TABLE public.templates IS 'Pre-workout nutrition templates with denormalized food data.';

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_template_foods_name ON public.template_foods (name);
CREATE INDEX IF NOT EXISTS idx_template_foods_active ON public.template_foods (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_template_foods_drink_pool ON public.template_foods (is_drink_pool) WHERE is_drink_pool = true;

CREATE INDEX IF NOT EXISTS idx_templates_phase ON public.templates (phase);
CREATE INDEX IF NOT EXISTS idx_templates_timing ON public.templates (timing_window);
CREATE INDEX IF NOT EXISTS idx_templates_category ON public.templates (base_category);
CREATE INDEX IF NOT EXISTS idx_templates_active ON public.templates (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_templates_meal_type ON public.templates (meal_type);
CREATE INDEX IF NOT EXISTS idx_templates_slug ON public.templates (slug);

CREATE INDEX IF NOT EXISTS idx_car_coach_athlete_status
  ON coach_athlete_relationships(coach_user_id, athlete_user_id, status);

-- ============================================================================
-- UPDATED_AT TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_template_foods_updated_at'
  ) THEN
    CREATE TRIGGER trigger_template_foods_updated_at
      BEFORE UPDATE ON public.template_foods
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_templates_updated_at'
  ) THEN
    CREATE TRIGGER trigger_templates_updated_at
      BEFORE UPDATE ON public.templates
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;

-- ============================================================================
-- RLS + POLICIES for template_foods & templates (public read, service write)
-- ============================================================================

ALTER TABLE public.template_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;

-- template_foods: public read
DROP POLICY IF EXISTS "template_foods_select_all" ON public.template_foods;
CREATE POLICY "template_foods_select_all" ON public.template_foods
  FOR SELECT USING (true);

-- template_foods: service/anon write
DROP POLICY IF EXISTS "template_foods_insert_service" ON public.template_foods;
CREATE POLICY "template_foods_insert_service" ON public.template_foods
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "template_foods_update_service" ON public.template_foods;
CREATE POLICY "template_foods_update_service" ON public.template_foods
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "template_foods_delete_service" ON public.template_foods;
CREATE POLICY "template_foods_delete_service" ON public.template_foods
  FOR DELETE USING (true);

-- templates: public read
DROP POLICY IF EXISTS "templates_select_all" ON public.templates;
CREATE POLICY "templates_select_all" ON public.templates
  FOR SELECT USING (true);

-- templates: service/anon write
DROP POLICY IF EXISTS "templates_insert_service" ON public.templates;
CREATE POLICY "templates_insert_service" ON public.templates
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "templates_update_service" ON public.templates;
CREATE POLICY "templates_update_service" ON public.templates
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "templates_delete_service" ON public.templates;
CREATE POLICY "templates_delete_service" ON public.templates
  FOR DELETE USING (true);

-- ============================================================================
-- GRANTS on new tables
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.template_foods TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.template_foods TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.template_foods TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.templates TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.templates TO service_role;

COMMIT;
