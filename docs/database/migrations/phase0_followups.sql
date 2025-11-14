-- Phase 0 Follow-ups (Feature Survey, Food Preferences, Product Types, Nutrition Tables)
-- Run after phase0_schema_refresh.sql has been applied.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL idle_in_transaction_session_timeout = '15min';

-------------------------------------------------------------------------------
-- Drop any remaining RLS policies (they should no longer be active)
-------------------------------------------------------------------------------
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I;', pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END$$;

-------------------------------------------------------------------------------
-- product_types → enum and remove lookup table
-------------------------------------------------------------------------------
DO $$
DECLARE
  type_values text[];
  val text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'product_type_enum') THEN
    SELECT array_agg(DISTINCT code ORDER BY code) INTO type_values FROM public.product_types;
    IF type_values IS NULL OR array_length(type_values, 1) = 0 THEN
      type_values := ARRAY['generic'];
    END IF;
    EXECUTE 'CREATE TYPE product_type_enum AS ENUM (' ||
      array_to_string(ARRAY(SELECT quote_literal(v) FROM unnest(type_values) AS v), ',') || ')';
  ELSE
    FOR val IN SELECT DISTINCT code FROM public.product_types LOOP
      EXECUTE format('ALTER TYPE product_type_enum ADD VALUE IF NOT EXISTS %L', val);
    END LOOP;
  END IF;
END$$;

ALTER TABLE public.foods ADD COLUMN IF NOT EXISTS product_type product_type_enum;
UPDATE public.foods f
SET product_type = pt.code::product_type_enum
FROM public.product_types pt
WHERE f.product_type IS NULL AND f.product_type_id = pt.id;

ALTER TABLE public.user_foods ADD COLUMN IF NOT EXISTS product_type product_type_enum;
UPDATE public.user_foods uf
SET product_type = pt.code::product_type_enum
FROM public.product_types pt
WHERE uf.product_type IS NULL AND uf.product_type_id = pt.id;

ALTER TABLE public.foods DROP CONSTRAINT IF EXISTS foods_product_type_id_fkey;
ALTER TABLE public.user_foods DROP CONSTRAINT IF EXISTS user_foods_product_type_id_fkey;

ALTER TABLE public.foods DROP COLUMN IF EXISTS product_type_id;
ALTER TABLE public.user_foods DROP COLUMN IF EXISTS product_type_id;

DROP TABLE IF EXISTS public.product_types;

-------------------------------------------------------------------------------
-- Feature survey responses → bigint PK + UUID ownership
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.feature_survey_responses CASCADE;

CREATE TABLE public.feature_survey_responses
(
    id                bigserial primary key,
    user_id           uuid      not null references public.users(id) on delete cascade,
    selected_features text      not null,
    voted_at          timestamptz not null default now()
);

CREATE UNIQUE INDEX idx_feature_survey_responses_user_id ON public.feature_survey_responses (user_id);
CREATE INDEX idx_feature_survey_responses_voted_at ON public.feature_survey_responses (voted_at);

-------------------------------------------------------------------------------
-- Food preferences tied to user_id instead of device_id
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.food_preferences CASCADE;

CREATE TABLE public.food_preferences
(
    id         uuid        primary key default gen_random_uuid(),
    user_id    uuid        not null references public.users(id) on delete cascade,
    food_name  text        not null,
    preference text        not null
        check (preference = ANY (ARRAY['like','dislike','willing_to_try'])),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

CREATE UNIQUE INDEX idx_food_preferences_user_food ON public.food_preferences (user_id, food_name);
CREATE INDEX idx_food_preferences_preference ON public.food_preferences (preference);

-------------------------------------------------------------------------------
-- Remove unused user_hidden_foods and nutrition_plans
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.user_hidden_foods CASCADE;
DROP TABLE IF EXISTS public.nutrition_plans CASCADE;

-------------------------------------------------------------------------------
-- Macro targets per activity
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.macro_targets_table CASCADE;

CREATE TABLE public.macro_targets_table
(
    activity_id              bigint      primary key references public.activities(id) on delete cascade,
    pre_run_carbs_g          numeric     not null check (pre_run_carbs_g >= 0),
    pre_run_protein_g        numeric     not null check (pre_run_protein_g >= 0),
    pre_run_fat_cap_g        numeric     not null check (pre_run_fat_cap_g >= 0),
    pre_run_fluids_ml        numeric     not null check (pre_run_fluids_ml >= 0),
    pre_run_sodium_mg        numeric     not null check (pre_run_sodium_mg >= 0),
    during_carb_rate_g_per_h numeric     not null check (during_carb_rate_g_per_h >= 0),
    during_carb_total_g      numeric     not null check (during_carb_total_g >= 0),
    during_fluid_rate_ml_per_h numeric   not null check (during_fluid_rate_ml_per_h >= 0),
    during_fluid_total_ml    numeric     not null check (during_fluid_total_ml >= 0),
    during_sodium_rate_mg_per_h numeric  not null check (during_sodium_rate_mg_per_h >= 0),
    during_sodium_total_mg   numeric     not null check (during_sodium_total_mg >= 0),
    during_mass_norm_rate_g_per_h numeric,
    post_run_carbs_g         numeric     not null check (post_run_carbs_g >= 0),
    post_run_protein_g       numeric     not null check (post_run_protein_g >= 0),
    post_run_fluids_ml       numeric     not null check (post_run_fluids_ml >= 0),
    post_run_sodium_mg       numeric     not null check (post_run_sodium_mg >= 0),
    distance_mi              numeric     not null check (distance_mi > 0),
    duration_h               numeric     not null check (duration_h > 0),
    pace_min_per_mile        numeric     not null check (pace_min_per_mile > 0),
    calories_gross_kcal      numeric     not null check (calories_gross_kcal >= 0),
    met                      numeric     not null check (met > 0),
    calculation_rule         text        not null,
    created_at               timestamptz not null default now(),
    updated_at               timestamptz not null default now()
);

CREATE INDEX idx_macro_targets_activity ON public.macro_targets_table (activity_id);

-------------------------------------------------------------------------------
-- Workout notes per activity
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.workout_notes CASCADE;

CREATE TABLE public.workout_notes
(
    id         bigserial primary key,
    activity_id bigint   not null references public.activities(id) on delete cascade,
    user_id    uuid      not null references public.users(id) on delete cascade,
    note_text  text      not null,
    rating     integer   check (rating IS NULL OR (rating BETWEEN 1 AND 5)),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

CREATE INDEX idx_workout_notes_activity ON public.workout_notes (activity_id);
CREATE INDEX idx_workout_notes_user ON public.workout_notes (user_id);

COMMIT;
