-- ============================================================================
-- PROD SCHEMA PARITY SCRIPT
-- ============================================================================
-- Run on: PRODUCTION Supabase SQL Editor
-- Purpose: Bring prod schema to match dev (idempotent, re-runnable)
-- Date: 2026-03-05
--
-- Changes:
--   1. Enum fix: add 'archived_for_brick' to activity_status_enum
--   2. Users table: 5 missing columns
--   3. Create template_foods table (40+ columns)
--   4. Create templates table (25+ columns)
--   5. Indexes for template_foods, templates, and coach_athlete_relationships
--   6. RLS policies for coach access on activities, events, carb loading
--   7. Grants on new tables
-- ============================================================================

-- ============================================================================
-- 1. ENUM FIX: Add 'archived_for_brick' to activity_status_enum
-- ============================================================================
-- Prod has camelCase 'archivedForBrick' but not snake_case 'archived_for_brick'
--
-- IMPORTANT: ALTER TYPE ... ADD VALUE cannot run inside a transaction block.
-- Run this statement FIRST, separately, before the rest of the script:
--
--   DO $$
--   BEGIN
--     IF NOT EXISTS (
--       SELECT 1 FROM pg_enum
--       WHERE enumtypid = 'activity_status_enum'::regtype
--         AND enumlabel = 'archived_for_brick'
--     ) THEN
--       ALTER TYPE activity_status_enum ADD VALUE 'archived_for_brick';
--     END IF;
--   END $$;
--
-- Then run everything below.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 2. USERS TABLE: 5 missing columns
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
COMMENT ON COLUMN public.users.default_running_pace_min_per_mile IS 'User default running pace in minutes per mile. Used to estimate workout duration from distance in new activity forms. Example: 8.5 = 8:30 min/mile pace.';
COMMENT ON COLUMN public.users.default_cycling_speed_mph IS 'User default cycling speed in miles per hour. Used to estimate workout duration from distance in new activity forms. Example: 18.5 mph.';
COMMENT ON COLUMN public.users.default_swimming_pace_per_100_sec IS 'User default swimming pace in seconds per 100 yards/meters. Used to estimate workout duration from distance in new activity forms. Example: 90 = 1:30 per 100 yards.';
COMMENT ON COLUMN public.users.nutrition_target_overrides IS 'User-configured nutrition target overrides. JSON with pre/during/post activity macro targets. Null = use algorithm defaults.';

-- ============================================================================
-- 3. CREATE template_foods TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.template_foods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  serving_size TEXT NOT NULL,
  serving_weight_g NUMERIC(6,1),

  -- Nutrition per serving
  calories INTEGER DEFAULT 0,
  carbs_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  protein_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  fat_g NUMERIC(6,1) NOT NULL DEFAULT 0,
  fiber_g NUMERIC(6,1) DEFAULT 0,
  sodium_mg NUMERIC(6,1) NOT NULL DEFAULT 0,
  fluid_ml NUMERIC(6,1) DEFAULT 0,

  -- Metadata
  allergens TEXT[] DEFAULT '{}',
  digestion_speed TEXT DEFAULT 'medium'
    CHECK (digestion_speed IN ('fast', 'medium', 'slow')),

  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Diet/preference columns (from 20260212000004)
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

  -- Drink pool columns (from 20260220000001)
  is_drink_pool BOOLEAN DEFAULT false,
  drink_pool_phases TEXT[] DEFAULT '{}',

  -- Beverage/fluid columns (from 20260220000006)
  is_liquid BOOLEAN DEFAULT false,

  -- LP solver columns (from 20260220000007)
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

  -- Indivisible flag (from 20260301000001)
  is_indivisible BOOLEAN DEFAULT false,

  -- Default during flag (from 20260301152000)
  default_during BOOLEAN NOT NULL DEFAULT false,

  -- Min servings during (from 20260305000000)
  min_servings_during NUMERIC(4,1) DEFAULT 1.0,

  CONSTRAINT uq_template_foods_name UNIQUE (name)
);

COMMENT ON TABLE public.template_foods IS 'Food ingredient catalog for nutrition templates. Nutrition data from USDA FoodData Central.';
COMMENT ON COLUMN public.template_foods.name IS 'Machine-readable identifier (e.g., white_bread)';
COMMENT ON COLUMN public.template_foods.allergens IS 'Array of allergen tags: gluten, dairy, eggs, peanuts, tree_nuts';
COMMENT ON COLUMN public.template_foods.digestion_speed IS 'How quickly food digests: fast (simple carbs), medium, slow (high fat/fiber)';
COMMENT ON COLUMN public.template_foods.is_indivisible IS 'Whether this food comes in discrete, sealed units that cannot be fractionally consumed (e.g., tablets, gel packets)';
COMMENT ON COLUMN public.template_foods.default_during IS 'Whether this food is part of the default during-activity recommendation set.';

-- ============================================================================
-- 4. CREATE templates TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,

  -- Phase & Timing
  phase TEXT NOT NULL DEFAULT 'before'
    CHECK (phase IN ('before', 'during', 'after', 'transition')),
  timing_window TEXT NOT NULL,
  timing_min_minutes INTEGER NOT NULL,
  timing_max_minutes INTEGER NOT NULL,
  meal_type TEXT NOT NULL DEFAULT 'snack'
    CHECK (meal_type IN ('top_up', 'snack', 'full_meal', 'during_fuel',
                          'recovery', 'transition_fuel')),

  -- Categorization
  base_category TEXT NOT NULL,
  digestion_speed TEXT DEFAULT 'medium'
    CHECK (digestion_speed IN ('fast', 'medium', 'slow')),
  allergens TEXT[] DEFAULT '{}',
  notes TEXT,

  -- DENORMALIZED FOODS (JSONB array)
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
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Additional columns from later migrations
  excluded_diets TEXT[] DEFAULT '{}',
  has_liquid_base BOOLEAN DEFAULT false,
  food_names TEXT[] DEFAULT '{}'
);

COMMENT ON TABLE public.templates IS 'Pre-workout nutrition templates with denormalized food data in JSONB. Each template is a curated food combination that scales to hit macro targets.';
COMMENT ON COLUMN public.templates.foods IS 'JSONB array of food items with per-serving nutrition and min/max servings for scaling';
COMMENT ON COLUMN public.templates.timing_window IS 'Display label: < 30 min, 30-60 min, 1-2 hours, 3-4 hours';
COMMENT ON COLUMN public.templates.meal_type IS 'Derived from timing: top_up (<1h), snack (1-2.5h), full_meal (2.5h+)';

-- ============================================================================
-- 5. INDEXES
-- ============================================================================

-- template_foods indexes
CREATE INDEX IF NOT EXISTS idx_template_foods_name ON public.template_foods (name);
CREATE INDEX IF NOT EXISTS idx_template_foods_active ON public.template_foods (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_template_foods_drink_pool ON public.template_foods (is_drink_pool) WHERE is_drink_pool = true;

-- templates indexes
CREATE INDEX IF NOT EXISTS idx_templates_phase ON public.templates (phase);
CREATE INDEX IF NOT EXISTS idx_templates_timing ON public.templates (timing_window);
CREATE INDEX IF NOT EXISTS idx_templates_category ON public.templates (base_category);
CREATE INDEX IF NOT EXISTS idx_templates_active ON public.templates (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_templates_meal_type ON public.templates (meal_type);
CREATE INDEX IF NOT EXISTS idx_templates_slug ON public.templates (slug);

-- coach_athlete_relationships composite index for RLS performance
CREATE INDEX IF NOT EXISTS idx_car_coach_athlete_status
  ON coach_athlete_relationships(coach_user_id, athlete_user_id, status);

-- ============================================================================
-- 6. UPDATED_AT TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Use DO block to check for existing triggers
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
-- 7. ROW LEVEL SECURITY - template_foods & templates
-- ============================================================================

ALTER TABLE public.template_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;

-- Public read access (templates are not user-specific)
DO $$ BEGIN
  DROP POLICY IF EXISTS "template_foods_select_all" ON public.template_foods;
  CREATE POLICY "template_foods_select_all" ON public.template_foods
    FOR SELECT USING (true);
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS "templates_select_all" ON public.templates;
  CREATE POLICY "templates_select_all" ON public.templates
    FOR SELECT USING (true);
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Service role / anon write access
DO $$ BEGIN
  DROP POLICY IF EXISTS "template_foods_insert_service" ON public.template_foods;
  CREATE POLICY "template_foods_insert_service" ON public.template_foods
    FOR INSERT WITH CHECK (auth.role() = 'service_role' OR auth.role() = 'anon');
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS "template_foods_update_service" ON public.template_foods;
  CREATE POLICY "template_foods_update_service" ON public.template_foods
    FOR UPDATE USING (auth.role() = 'service_role' OR auth.role() = 'anon');
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS "template_foods_delete_service" ON public.template_foods;
  CREATE POLICY "template_foods_delete_service" ON public.template_foods
    FOR DELETE USING (auth.role() = 'service_role' OR auth.role() = 'anon');
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS "templates_insert_service" ON public.templates;
  CREATE POLICY "templates_insert_service" ON public.templates
    FOR INSERT WITH CHECK (auth.role() = 'service_role' OR auth.role() = 'anon');
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS "templates_update_service" ON public.templates;
  CREATE POLICY "templates_update_service" ON public.templates
    FOR UPDATE USING (auth.role() = 'service_role' OR auth.role() = 'anon');
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS "templates_delete_service" ON public.templates;
  CREATE POLICY "templates_delete_service" ON public.templates
    FOR DELETE USING (auth.role() = 'service_role' OR auth.role() = 'anon');
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- ============================================================================
-- 8. GRANTS on new tables
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.template_foods TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.template_foods TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.template_foods TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.templates TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.templates TO service_role;

-- ============================================================================
-- 9. COACH ACCESS RLS POLICIES (from 20260301200001)
-- ============================================================================
-- Idempotent: drops all old and new policy names before recreating

-- ---- ACTIVITIES ----
DROP POLICY IF EXISTS "activities_select_policy" ON activities;
DROP POLICY IF EXISTS "activities_insert_policy" ON activities;
DROP POLICY IF EXISTS "activities_update_policy" ON activities;
DROP POLICY IF EXISTS "activities_delete_policy" ON activities;

CREATE POLICY "activities_select_policy" ON activities FOR SELECT USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

CREATE POLICY "activities_insert_policy" ON activities FOR INSERT WITH CHECK (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

CREATE POLICY "activities_update_policy" ON activities FOR UPDATE USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

CREATE POLICY "activities_delete_policy" ON activities FOR DELETE USING (
  user_id = current_setting('app.user_id', true)::uuid
);

-- ---- EVENTS ----
DROP POLICY IF EXISTS "events_select_policy" ON events;
DROP POLICY IF EXISTS "events_insert_policy" ON events;
DROP POLICY IF EXISTS "events_update_policy" ON events;
DROP POLICY IF EXISTS "events_delete_policy" ON events;
DROP POLICY IF EXISTS "Users can view their own events" ON events;
DROP POLICY IF EXISTS "Users can insert their own events" ON events;
DROP POLICY IF EXISTS "Users can update their own events" ON events;
DROP POLICY IF EXISTS "Users can delete their own events" ON events;

CREATE POLICY "events_select_policy" ON events FOR SELECT USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = events.user_id
      AND status = 'active'
  )
);

CREATE POLICY "events_insert_policy" ON events FOR INSERT WITH CHECK (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = events.user_id
      AND status = 'active'
  )
);

CREATE POLICY "events_update_policy" ON events FOR UPDATE USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = events.user_id
      AND status = 'active'
  )
);

CREATE POLICY "events_delete_policy" ON events FOR DELETE USING (
  user_id = current_setting('app.user_id', true)::uuid
);

-- ---- CARB_LOADING_PLANS ----
DROP POLICY IF EXISTS "carb_plans_select_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_insert_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_update_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_delete_policy" ON carb_loading_plans;

CREATE POLICY "carb_plans_select_policy" ON carb_loading_plans FOR SELECT USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

CREATE POLICY "carb_plans_insert_policy" ON carb_loading_plans FOR INSERT WITH CHECK (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

CREATE POLICY "carb_plans_update_policy" ON carb_loading_plans FOR UPDATE USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

CREATE POLICY "carb_plans_delete_policy" ON carb_loading_plans FOR DELETE USING (
  user_id = current_setting('app.user_id', true)::uuid
);

-- ---- CARB_LOADING_DAYS ----
DROP POLICY IF EXISTS "carb_days_select_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_insert_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_update_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_delete_policy" ON carb_loading_days;

CREATE POLICY "carb_days_select_policy" ON carb_loading_days FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_days_insert_policy" ON carb_loading_days FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_days_update_policy" ON carb_loading_days FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_days_delete_policy" ON carb_loading_days FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
  )
);

-- ---- CARB_LOADING_DAY_MEALS ----
DROP POLICY IF EXISTS "carb_loading_day_meals_device_read" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_insert" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_update" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_delete" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_meals_select_policy" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_meals_insert_policy" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_meals_update_policy" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_meals_delete_policy" ON carb_loading_day_meals;

CREATE POLICY "carb_meals_select_policy" ON carb_loading_day_meals FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        p.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_meals_insert_policy" ON carb_loading_day_meals FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        p.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_meals_update_policy" ON carb_loading_day_meals FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        p.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_meals_delete_policy" ON carb_loading_day_meals FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND p.user_id = current_setting('app.user_id', true)::uuid
  )
);

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES (run after to confirm)
-- ============================================================================
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'template_foods' ORDER BY ordinal_position;
--
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'templates' ORDER BY ordinal_position;
--
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'users'
--   AND column_name IN ('unit_system', 'default_running_pace_min_per_mile',
--       'default_cycling_speed_mph', 'default_swimming_pace_per_100_sec',
--       'nutrition_target_overrides');
--
-- SELECT enumlabel FROM pg_enum
--   WHERE enumtypid = 'activity_status_enum'::regtype
--   ORDER BY enumlabel;
