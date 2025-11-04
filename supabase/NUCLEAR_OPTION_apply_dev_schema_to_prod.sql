-- ============================================================================
-- NUCLEAR OPTION: Complete PROD Reset with DEV Schema
-- Date: 2025-10-30
-- Purpose: Drop everything in PROD and apply clean DEV schema
-- WARNING: This will DELETE ALL DATA except what's seeded below
-- ============================================================================

-- ============================================================================
-- STEP 1: Drop ALL tables (CASCADE to handle foreign keys)
-- ============================================================================

DROP TABLE IF EXISTS public.carb_loading_day_meals CASCADE;
DROP TABLE IF EXISTS public.carb_loading_user_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.carb_loading_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.carb_loading_user_foods CASCADE;
DROP TABLE IF EXISTS public.carb_loading_foods CASCADE;
DROP TABLE IF EXISTS public.meal_types CASCADE;
DROP TABLE IF EXISTS public.activity_completions CASCADE;
DROP TABLE IF EXISTS public.carb_loading_days CASCADE;
DROP TABLE IF EXISTS public.carb_loading_plans CASCADE;
DROP TABLE IF EXISTS public.events CASCADE;
DROP TABLE IF EXISTS public.activities CASCADE;
DROP TABLE IF EXISTS public.workout_notes CASCADE;
DROP TABLE IF EXISTS public.macro_targets_table CASCADE;
DROP TABLE IF EXISTS public.nutrition_plans CASCADE;
DROP TABLE IF EXISTS public.user_hidden_foods CASCADE;
DROP TABLE IF EXISTS public.user_food_categories CASCADE;
DROP TABLE IF EXISTS public.user_foods CASCADE;
DROP TABLE IF EXISTS public.food_categories CASCADE;
DROP TABLE IF EXISTS public.foods CASCADE;
DROP TABLE IF EXISTS public.product_types CASCADE;
DROP TABLE IF EXISTS public.food_preferences CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.feedback CASCADE;
DROP TABLE IF EXISTS public.edge_functions CASCADE;
DROP TABLE IF EXISTS public.app_content CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS public.update_food_preferences_updated_at() CASCADE;

-- ============================================================================
-- STEP 2: Create helper functions
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_food_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 3: Create all tables with DEV schema
-- ============================================================================

-- USERS TABLE
CREATE TABLE public.users (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  device_id text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  gender text CONSTRAINT users_gender_check CHECK (gender IN ('male', 'female', 'other')),
  birthday date,
  height_feet integer,
  height_inches integer,
  weight_pounds numeric(5, 2),
  runs_with_water_bottle boolean DEFAULT false,
  food_preferences jsonb DEFAULT '{}'::jsonb,
  preferred_distance_unit text DEFAULT 'miles' CONSTRAINT users_preferred_distance_unit_check CHECK (preferred_distance_unit IN ('miles', 'kilometers')),
  preferred_pace_unit text DEFAULT 'min_per_mile' CONSTRAINT users_preferred_pace_unit_check CHECK (preferred_pace_unit IN ('min_per_mile', 'min_per_km')),
  gut_training_level text DEFAULT 'moderate' CONSTRAINT users_gut_training_level_check CHECK (gut_training_level IN ('low', 'moderate', 'high')),
  onboarding_completed boolean DEFAULT false,
  last_active_at timestamp with time zone DEFAULT now(),
  app_version text,
  notifications_enabled boolean DEFAULT false,
  default_reminder_day integer DEFAULT 4,
  default_reminder_hour integer DEFAULT 17,
  default_reminder_minute integer DEFAULT 0,
  default_reminder_recurring boolean DEFAULT false
);

CREATE INDEX idx_users_device_id ON public.users(device_id);
CREATE INDEX idx_users_updated_at ON public.users(updated_at);

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- APP_CONTENT TABLE
CREATE TABLE public.app_content (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  version integer DEFAULT 1 NOT NULL,
  environment text DEFAULT 'production' NOT NULL,
  locale text DEFAULT 'en' NOT NULL,
  content jsonb NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid
);

CREATE INDEX idx_app_content_active ON public.app_content(is_active);
CREATE INDEX idx_app_content_env_locale ON public.app_content(environment, locale);
CREATE INDEX idx_app_content_version ON public.app_content(version);

CREATE TRIGGER update_app_content_updated_at BEFORE UPDATE ON public.app_content
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- CATEGORIES TABLE
CREATE TABLE public.categories (
  id integer NOT NULL PRIMARY KEY,
  name text NOT NULL
);

-- EDGE_FUNCTIONS TABLE
CREATE TABLE public.edge_functions (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  name text NOT NULL UNIQUE,
  code text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- FEEDBACK TABLE
CREATE TABLE public.feedback (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  satisfaction_level integer,
  satisfaction_emoji text,
  satisfaction_label text,
  confidence_level integer,
  confidence_label text,
  reuse_intent text,
  reminder_requested boolean DEFAULT false,
  missed_reasons text,
  missed_other text,
  reminder_day_of_week integer,
  reminder_hour integer DEFAULT 17,
  reminder_minute integer DEFAULT 0,
  reminder_recurring boolean DEFAULT false,
  plan_name text,
  user_name text,
  timestamp timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

CREATE INDEX idx_feedback_created_at ON public.feedback(created_at);
CREATE INDEX idx_feedback_satisfaction_level ON public.feedback(satisfaction_level);
CREATE INDEX idx_feedback_timestamp ON public.feedback(timestamp);
CREATE INDEX idx_feedback_user_name ON public.feedback(user_name);

-- FOOD_PREFERENCES TABLE
CREATE TABLE public.food_preferences (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  device_id text NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
  food_name text NOT NULL,
  preference text NOT NULL CONSTRAINT food_preferences_preference_check CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE UNIQUE INDEX idx_food_preferences_device_food ON public.food_preferences(device_id, food_name);
CREATE INDEX idx_food_preferences_device_id ON public.food_preferences(device_id);
CREATE INDEX idx_food_preferences_preference ON public.food_preferences(preference);

CREATE TRIGGER update_food_preferences_updated_at BEFORE UPDATE ON public.food_preferences
  FOR EACH ROW EXECUTE FUNCTION public.update_food_preferences_updated_at();

-- PRODUCT_TYPES TABLE
CREATE TABLE public.product_types (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  name_plural text NOT NULL,
  sort_order integer,
  created_at timestamp with time zone DEFAULT now()
);

-- FOODS TABLE
CREATE TABLE public.foods (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  name text,
  image_address text,
  created_at timestamp with time zone DEFAULT now(),
  serving_amount numeric,
  max_servings_before integer,
  max_servings_during integer,
  sodium_mg bigint,
  caffeine_mg bigint,
  potassium_mg bigint,
  fat_per_serving numeric(10, 2),
  carbs_per_serving numeric(10, 2),
  protein_per_serving numeric(10, 2),
  calories_per_serving integer,
  fluid_ml_per_serving numeric(10, 1),
  show_in_preferences boolean DEFAULT false,
  display_name varchar(100),
  max_servings_after integer,
  is_electrolyte boolean DEFAULT false,
  display_name_plural varchar(100),
  to_exclude_from_solver boolean DEFAULT false,
  product_type_id uuid REFERENCES public.product_types(id),
  description text,
  serving_description text,
  serving_size varchar(50),
  is_essential boolean DEFAULT false,
  is_other_food boolean,
  cycling_suitable boolean DEFAULT true,
  swimming_suitable boolean DEFAULT true,
  suitable_for_activities jsonb
);

CREATE UNIQUE INDEX uq_foods_lower_name ON public.foods(lower(name));
CREATE INDEX idx_foods_product_type_id ON public.foods(product_type_id);

COMMENT ON COLUMN public.foods.show_in_preferences IS 'Whether this food should be shown in the onboarding food preferences screen';
COMMENT ON COLUMN public.foods.is_essential IS 'No need to present to user to set preferences';

-- FOOD_CATEGORIES TABLE
CREATE TABLE public.food_categories (
  food_id uuid NOT NULL REFERENCES public.foods(id) ON DELETE CASCADE,
  category_id integer NOT NULL REFERENCES public.categories(id),
  PRIMARY KEY (food_id, category_id)
);

CREATE INDEX idx_food_categories_food ON public.food_categories(food_id);
CREATE INDEX idx_food_categories_category_id ON public.food_categories(category_id);

-- USER_FOODS TABLE
CREATE TABLE public.user_foods (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  device_id text NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
  client_food_id text,
  barcode text,
  name text NOT NULL,
  display_name text,
  display_name_plural text,
  description text,
  image_address text,
  serving_amount numeric,
  serving_unit text,
  calories_per_serving integer,
  carbs_per_serving numeric(10, 2),
  protein_per_serving numeric(10, 2),
  fat_per_serving numeric(10, 2),
  sodium_mg bigint,
  fluid_ml_per_serving numeric(10, 1),
  product_type_id uuid REFERENCES public.product_types(id),
  is_electrolyte boolean DEFAULT false,
  to_exclude_from_solver boolean DEFAULT false,
  is_deleted boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  client_updated_at timestamp with time zone,
  cycling_suitable boolean DEFAULT true,
  swimming_suitable boolean DEFAULT true,
  suitable_for_activities jsonb
);

CREATE INDEX idx_user_foods_device ON public.user_foods(device_id);
CREATE INDEX idx_user_foods_barcode ON public.user_foods(barcode);
CREATE UNIQUE INDEX uq_user_foods_device_clientid ON public.user_foods(device_id, client_food_id);
CREATE INDEX idx_user_foods_device_not_deleted ON public.user_foods(device_id) WHERE is_deleted = false;

-- USER_FOOD_CATEGORIES TABLE
CREATE TABLE public.user_food_categories (
  user_food_id uuid NOT NULL REFERENCES public.user_foods(id) ON DELETE CASCADE,
  category_id integer NOT NULL REFERENCES public.categories(id),
  PRIMARY KEY (user_food_id, category_id)
);

CREATE INDEX idx_user_food_categories_user_food ON public.user_food_categories(user_food_id);
CREATE INDEX idx_user_food_categories_category ON public.user_food_categories(category_id);

-- USER_HIDDEN_FOODS TABLE
CREATE TABLE public.user_hidden_foods (
  device_id text NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
  food_id uuid NOT NULL REFERENCES public.foods(id) ON DELETE CASCADE,
  PRIMARY KEY (device_id, food_id)
);

-- ACTIVITIES TABLE
CREATE TABLE public.activities (
  id text NOT NULL PRIMARY KEY,
  user_id text NOT NULL,
  activity_type text NOT NULL CONSTRAINT activity_type_check CHECK (activity_type IN ('running', 'event')),
  title text NOT NULL,
  scheduled_date_time timestamp NOT NULL,
  status text DEFAULT 'planned' CONSTRAINT status_check CHECK (status IN ('planned', 'in_progress', 'completed', 'skipped')),
  distance_miles real,
  duration_minutes integer,
  pace_target_minutes_per_mile real,
  intensity_level text CONSTRAINT intensity_check CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race')),
  completed_at timestamp,
  completion_rating integer CONSTRAINT rating_check CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5)),
  completion_notes text,
  actual_distance_miles real,
  actual_duration_minutes integer,
  notes text,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp DEFAULT CURRENT_TIMESTAMP,
  deleted_at timestamp
);

CREATE INDEX idx_activities_user ON public.activities(user_id);
CREATE INDEX idx_activities_scheduled ON public.activities(scheduled_date_time);
CREATE INDEX idx_activities_type ON public.activities(activity_type);
CREATE INDEX idx_activities_status ON public.activities(status);

COMMENT ON TABLE public.activities IS 'All calendar entries including workouts and events';
COMMENT ON COLUMN public.activities.activity_type IS 'Type: running (workout) or event (race)';
COMMENT ON COLUMN public.activities.status IS 'Current status: planned, in_progress, completed, skipped';

-- NUTRITION_PLANS TABLE
CREATE TABLE public.nutrition_plans (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  device_id text NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
  plan_data jsonb NOT NULL,
  distance_miles numeric(5, 2),
  pace_minutes_per_mile numeric(5, 2),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  plan_id text NOT NULL,
  plan_name text NOT NULL,
  total_calories integer,
  notes text,
  version integer DEFAULT 1,
  last_modified_by text,
  client_updated_at timestamp with time zone,
  is_deleted boolean DEFAULT false,
  conflict_resolution text,
  activity_id text REFERENCES public.activities(id) ON DELETE SET NULL,
  UNIQUE (device_id, plan_id)
);

CREATE INDEX idx_nutrition_plans_created_at ON public.nutrition_plans(created_at DESC);
CREATE INDEX idx_nutrition_plans_device_id ON public.nutrition_plans(device_id);
CREATE INDEX idx_nutrition_plans_device_updated ON public.nutrition_plans(device_id ASC, updated_at DESC);
CREATE INDEX idx_nutrition_plans_plan_id ON public.nutrition_plans(plan_id);
CREATE INDEX idx_nutrition_plans_updated_at ON public.nutrition_plans(updated_at DESC);
CREATE INDEX idx_nutrition_plans_activity_id ON public.nutrition_plans(activity_id);

CREATE TRIGGER update_nutrition_plans_updated_at BEFORE UPDATE ON public.nutrition_plans
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

COMMENT ON COLUMN public.nutrition_plans.activity_id IS 'Links nutrition plan to a calendar activity/event. Nullable to support standalone plans.';

-- EVENTS TABLE
CREATE TABLE public.events (
  id text NOT NULL PRIMARY KEY,
  activity_id text NOT NULL UNIQUE REFERENCES public.activities(id) ON DELETE CASCADE,
  event_type text NOT NULL CONSTRAINT event_type_check CHECK (event_type IN ('marathon', 'half_marathon', '10k', '5k', 'ultra_50k', 'ultra_50m', 'ultra_100k', 'ultra_100m', 'custom')),
  event_subtype text,
  event_name text,
  location text,
  registration_url text,
  start_time text,
  goal_time_minutes integer,
  goal_pace_minutes_per_mile real,
  predicted_finish_time_minutes integer,
  has_carb_loading boolean DEFAULT false,
  carb_loading_days integer CONSTRAINT carb_days_check CHECK (carb_loading_days IS NULL OR carb_loading_days IN (1, 2, 3, 7)),
  carb_loading_start_date timestamp,
  bib_number text,
  wave_start_time text,
  packet_pickup_info text,
  actual_finish_time_minutes integer,
  final_placement integer,
  age_group_placement integer,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp DEFAULT CURRENT_TIMESTAMP,
  has_nutrition_plan boolean DEFAULT false
);

CREATE INDEX idx_events_activity ON public.events(activity_id);
CREATE INDEX idx_events_type ON public.events(event_type);
CREATE INDEX idx_events_carb_loading ON public.events(has_carb_loading) WHERE has_carb_loading = true;

COMMENT ON TABLE public.events IS 'Specialized event data for races and competitions';
COMMENT ON COLUMN public.events.activity_id IS 'One-to-one link to activities table';
COMMENT ON COLUMN public.events.has_carb_loading IS 'Whether this event has an associated carb loading plan';
COMMENT ON COLUMN public.events.has_nutrition_plan IS 'Indicates whether this event has an associated nutrition plan';

-- CARB_LOADING_PLANS TABLE
CREATE TABLE public.carb_loading_plans (
  id text NOT NULL PRIMARY KEY,
  event_id text REFERENCES public.events(id) ON DELETE CASCADE,
  user_id text NOT NULL,
  total_days integer NOT NULL CONSTRAINT total_days_check CHECK (total_days IN (1, 2, 3, 7)),
  start_date timestamp NOT NULL,
  end_date timestamp NOT NULL,
  daily_carb_target_grams integer NOT NULL,
  daily_calorie_target integer,
  generated_at timestamp NOT NULL,
  algorithm_version text DEFAULT 'v1.0',
  adherence_score real CONSTRAINT adherence_check CHECK (adherence_score IS NULL OR (adherence_score >= 0.0 AND adherence_score <= 1.0)),
  completed_at timestamp
);

CREATE INDEX idx_carb_plans_event ON public.carb_loading_plans(event_id);
CREATE INDEX idx_carb_plans_user ON public.carb_loading_plans(user_id);
CREATE INDEX idx_carb_plans_dates ON public.carb_loading_plans(start_date, end_date);

COMMENT ON TABLE public.carb_loading_plans IS 'Carb loading plans linked to specific events';

-- CARB_LOADING_DAYS TABLE
CREATE TABLE public.carb_loading_days (
  id text NOT NULL PRIMARY KEY,
  carb_loading_plan_id text NOT NULL REFERENCES public.carb_loading_plans(id) ON DELETE CASCADE,
  plan_date timestamp NOT NULL,
  day_number integer NOT NULL CONSTRAINT day_number_check CHECK (day_number > 0),
  carb_target_grams integer NOT NULL CONSTRAINT carb_target_check CHECK (carb_target_grams > 0),
  calorie_target integer,
  meal_count integer DEFAULT 6 CONSTRAINT meal_count_check CHECK (meal_count > 0),
  breakfast_percent real DEFAULT 0.25,
  morning_snack_percent real DEFAULT 0.10,
  lunch_percent real DEFAULT 0.25,
  afternoon_snack_percent real DEFAULT 0.15,
  dinner_percent real DEFAULT 0.20,
  evening_snack_percent real DEFAULT 0.05,
  logged_carbs_grams integer DEFAULT 0,
  logged_calories integer DEFAULT 0,
  completed boolean DEFAULT false,
  carb_protocol_g_per_kg real DEFAULT 8.0 NOT NULL,
  UNIQUE (carb_loading_plan_id, plan_date)
);

CREATE INDEX idx_carb_days_plan ON public.carb_loading_days(carb_loading_plan_id);
CREATE INDEX idx_carb_days_date ON public.carb_loading_days(plan_date);
CREATE INDEX idx_carb_days_completed ON public.carb_loading_days(completed);

-- ACTIVITY_COMPLETIONS TABLE
CREATE TABLE public.activity_completions (
  id text NOT NULL PRIMARY KEY,
  activity_id text NOT NULL UNIQUE REFERENCES public.activities(id) ON DELETE CASCADE,
  completed_at timestamp NOT NULL,
  actual_distance_miles real,
  actual_duration_minutes integer,
  average_pace_minutes_per_mile real,
  completion_rating integer CONSTRAINT rating_check CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5)),
  completion_notes text,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_activity_completions_activity ON public.activity_completions(activity_id);
CREATE INDEX idx_activity_completions_date ON public.activity_completions(completed_at);

COMMENT ON TABLE public.activity_completions IS 'Completion records for activities';

-- MEAL_TYPES TABLE
CREATE TABLE public.meal_types (
  id integer NOT NULL PRIMARY KEY,
  name text NOT NULL UNIQUE,
  display_name text NOT NULL
);

COMMENT ON TABLE public.meal_types IS 'Meal categories for carb loading feature';

-- CARB_LOADING_FOODS TABLE
CREATE TABLE public.carb_loading_foods (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  name text NOT NULL,
  display_name text NOT NULL,
  display_name_plural text,
  carbs_per_serving real NOT NULL CONSTRAINT carbs_positive CHECK (carbs_per_serving > 0),
  image_address text,
  is_default boolean DEFAULT true,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_carb_loading_foods_name ON public.carb_loading_foods(name);
CREATE INDEX idx_carb_loading_foods_default ON public.carb_loading_foods(is_default);

COMMENT ON TABLE public.carb_loading_foods IS 'Global default carb loading foods';

-- CARB_LOADING_USER_FOODS TABLE
CREATE TABLE public.carb_loading_user_foods (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  device_id text NOT NULL,
  client_food_id text,
  name text NOT NULL,
  display_name text NOT NULL,
  display_name_plural text,
  carbs_per_serving real NOT NULL CONSTRAINT carbs_positive CHECK (carbs_per_serving > 0),
  image_address text,
  barcode text,
  source_food_id uuid REFERENCES public.foods(id),
  source_user_food_id uuid REFERENCES public.user_foods(id),
  is_deleted boolean DEFAULT false,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_carb_loading_user_foods_device ON public.carb_loading_user_foods(device_id);
CREATE INDEX idx_carb_loading_user_foods_deleted ON public.carb_loading_user_foods(is_deleted);
CREATE INDEX idx_carb_loading_user_foods_barcode ON public.carb_loading_user_foods(barcode) WHERE barcode IS NOT NULL;

-- CARB_LOADING_FOOD_MEAL_TYPES TABLE
CREATE TABLE public.carb_loading_food_meal_types (
  carb_loading_food_id uuid NOT NULL REFERENCES public.carb_loading_foods(id) ON DELETE CASCADE,
  meal_type_id integer NOT NULL REFERENCES public.meal_types(id),
  PRIMARY KEY (carb_loading_food_id, meal_type_id)
);

CREATE INDEX idx_carb_food_meal_types_food ON public.carb_loading_food_meal_types(carb_loading_food_id);
CREATE INDEX idx_carb_food_meal_types_meal ON public.carb_loading_food_meal_types(meal_type_id);

-- CARB_LOADING_USER_FOOD_MEAL_TYPES TABLE
CREATE TABLE public.carb_loading_user_food_meal_types (
  carb_loading_user_food_id uuid NOT NULL REFERENCES public.carb_loading_user_foods(id) ON DELETE CASCADE,
  meal_type_id integer NOT NULL REFERENCES public.meal_types(id),
  PRIMARY KEY (carb_loading_user_food_id, meal_type_id)
);

CREATE INDEX idx_carb_user_food_meal_types_food ON public.carb_loading_user_food_meal_types(carb_loading_user_food_id);
CREATE INDEX idx_carb_user_food_meal_types_meal ON public.carb_loading_user_food_meal_types(meal_type_id);

-- CARB_LOADING_DAY_MEALS TABLE
CREATE TABLE public.carb_loading_day_meals (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  carb_loading_day_id text NOT NULL REFERENCES public.carb_loading_days(id) ON DELETE CASCADE,
  meal_type_id integer NOT NULL REFERENCES public.meal_types(id),
  carb_loading_food_id uuid REFERENCES public.carb_loading_foods(id),
  carb_loading_user_food_id uuid REFERENCES public.carb_loading_user_foods(id),
  food_display_name text,
  quantity integer DEFAULT 1 CONSTRAINT quantity_positive CHECK (quantity > 0),
  carbs_consumed real NOT NULL CONSTRAINT carbs_positive CHECK (carbs_consumed >= 0),
  created_at timestamp DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT one_food_type CHECK (
    (carb_loading_food_id IS NOT NULL AND carb_loading_user_food_id IS NULL) OR
    (carb_loading_food_id IS NULL AND carb_loading_user_food_id IS NOT NULL)
  )
);

CREATE INDEX idx_carb_day_meals_day ON public.carb_loading_day_meals(carb_loading_day_id);
CREATE INDEX idx_carb_day_meals_meal_type ON public.carb_loading_day_meals(meal_type_id);
CREATE INDEX idx_carb_day_meals_food ON public.carb_loading_day_meals(carb_loading_food_id) WHERE carb_loading_food_id IS NOT NULL;
CREATE INDEX idx_carb_day_meals_user_food ON public.carb_loading_day_meals(carb_loading_user_food_id) WHERE carb_loading_user_food_id IS NOT NULL;

-- MACRO_TARGETS_TABLE
CREATE TABLE public.macro_targets_table (
  id text NOT NULL PRIMARY KEY CONSTRAINT macro_targets_table_id_check CHECK (length(id) >= 1 AND length(id) <= 50),
  pre_run_carbs_g numeric NOT NULL CONSTRAINT check_pre_run_carbs_positive CHECK (pre_run_carbs_g >= 0),
  pre_run_protein_g numeric NOT NULL CONSTRAINT check_pre_run_protein_positive CHECK (pre_run_protein_g >= 0),
  pre_run_fat_cap_g numeric NOT NULL CONSTRAINT check_pre_run_fat_positive CHECK (pre_run_fat_cap_g >= 0),
  pre_run_fluids_ml numeric NOT NULL CONSTRAINT check_pre_run_fluids_positive CHECK (pre_run_fluids_ml >= 0),
  pre_run_sodium_mg numeric NOT NULL CONSTRAINT check_pre_run_sodium_positive CHECK (pre_run_sodium_mg >= 0),
  during_carb_rate_g_per_h numeric NOT NULL CONSTRAINT check_during_carb_rate_positive CHECK (during_carb_rate_g_per_h >= 0),
  during_carb_total_g numeric NOT NULL CONSTRAINT check_during_carb_total_positive CHECK (during_carb_total_g >= 0),
  during_fluid_rate_ml_per_h numeric NOT NULL CONSTRAINT check_during_fluid_rate_positive CHECK (during_fluid_rate_ml_per_h >= 0),
  during_fluid_total_ml numeric NOT NULL CONSTRAINT check_during_fluid_total_positive CHECK (during_fluid_total_ml >= 0),
  during_sodium_rate_mg_per_h numeric NOT NULL CONSTRAINT check_during_sodium_rate_positive CHECK (during_sodium_rate_mg_per_h >= 0),
  during_sodium_total_mg numeric NOT NULL CONSTRAINT check_during_sodium_total_positive CHECK (during_sodium_total_mg >= 0),
  during_mass_norm_rate_g_per_h numeric,
  post_run_carbs_g numeric NOT NULL CONSTRAINT check_post_run_carbs_positive CHECK (post_run_carbs_g >= 0),
  post_run_protein_g numeric NOT NULL CONSTRAINT check_post_run_protein_positive CHECK (post_run_protein_g >= 0),
  post_run_fluids_ml numeric NOT NULL CONSTRAINT check_post_run_fluids_positive CHECK (post_run_fluids_ml >= 0),
  post_run_sodium_mg numeric NOT NULL CONSTRAINT check_post_run_sodium_positive CHECK (post_run_sodium_mg >= 0),
  distance_mi numeric NOT NULL CONSTRAINT check_distance_positive CHECK (distance_mi > 0),
  duration_h numeric NOT NULL CONSTRAINT check_duration_positive CHECK (duration_h > 0),
  pace_min_per_mile numeric NOT NULL CONSTRAINT check_pace_positive CHECK (pace_min_per_mile > 0),
  calories_gross_kcal numeric NOT NULL CONSTRAINT check_calories_positive CHECK (calories_gross_kcal >= 0),
  met numeric NOT NULL CONSTRAINT check_met_positive CHECK (met > 0),
  calculation_rule text NOT NULL,
  timestamp timestamp NOT NULL,
  is_user_modified boolean DEFAULT false NOT NULL,
  modified_fields text DEFAULT '' NOT NULL
);

CREATE INDEX idx_macro_targets_timestamp ON public.macro_targets_table(timestamp);
CREATE INDEX idx_macro_targets_distance ON public.macro_targets_table(distance_mi);

COMMENT ON TABLE public.macro_targets_table IS 'Calculated nutrition targets for running sessions';

-- WORKOUT_NOTES TABLE
CREATE TABLE public.workout_notes (
  id text NOT NULL PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plan_id text,
  note_text text NOT NULL,
  rating integer CONSTRAINT workout_notes_rating_check CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5)),
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);

CREATE INDEX idx_workout_notes_user ON public.workout_notes(user_id);
CREATE INDEX idx_workout_notes_plan ON public.workout_notes(plan_id) WHERE plan_id IS NOT NULL;
CREATE INDEX idx_workout_notes_created ON public.workout_notes(created_at);

COMMENT ON TABLE public.workout_notes IS 'User workout journal entries';

-- ============================================================================
-- STEP 4: Enable RLS on all tables
-- ============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_functions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_food_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_hidden_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_user_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_food_meal_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_user_food_meal_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_day_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.macro_targets_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_notes ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 5: Create RLS Policies
-- ============================================================================

-- Users
CREATE POLICY "Users can read own data" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert own data" ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own data" ON public.users FOR UPDATE USING (true);

-- App Content
CREATE POLICY "Allow public read access to app_content" ON public.app_content FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert to app_content" ON public.app_content FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated update to app_content" ON public.app_content FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Anyone can read app_content" ON public.app_content FOR SELECT USING (true);
CREATE POLICY "Dev: anon can modify app_content" ON public.app_content FOR ALL TO anon USING (true) WITH CHECK (true);

-- Categories
CREATE POLICY "Anyone can read categories" ON public.categories FOR SELECT USING (true);

-- Edge Functions
CREATE POLICY "Anyone can read edge_functions" ON public.edge_functions FOR SELECT USING (true);
CREATE POLICY "Dev: anon can modify edge_functions" ON public.edge_functions FOR ALL TO anon USING (true) WITH CHECK (true);

-- Feedback
CREATE POLICY "Allow all operations on feedback" ON public.feedback FOR ALL USING (true);

-- Food Preferences
CREATE POLICY "Allow all operations on food_preferences" ON public.food_preferences FOR ALL USING (true) WITH CHECK (true);

-- Foods
CREATE POLICY "Anyone can read foods" ON public.foods FOR SELECT USING (true);
CREATE POLICY "Dev: anon can modify foods" ON public.foods FOR ALL TO anon USING (true) WITH CHECK (true);

-- Food Categories
CREATE POLICY "Anyone can read food_categories" ON public.food_categories FOR SELECT USING (true);
CREATE POLICY "Dev: anon can modify food_categories" ON public.food_categories FOR ALL TO anon USING (true) WITH CHECK (true);

-- User Foods - no policies needed, will be accessed via service role

-- Activities
CREATE POLICY activities_select_policy ON public.activities FOR SELECT USING (user_id = current_setting('app.user_id', true));
CREATE POLICY activities_insert_policy ON public.activities FOR INSERT WITH CHECK (user_id = current_setting('app.user_id', true));
CREATE POLICY activities_update_policy ON public.activities FOR UPDATE USING (user_id = current_setting('app.user_id', true));
CREATE POLICY activities_delete_policy ON public.activities FOR DELETE USING (user_id = current_setting('app.user_id', true));

-- Nutrition Plans
CREATE POLICY "Users can read own plans" ON public.nutrition_plans FOR SELECT USING (true);
CREATE POLICY "Users can insert own plans" ON public.nutrition_plans FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own plans" ON public.nutrition_plans FOR UPDATE USING (true);
CREATE POLICY "Users can delete own plans" ON public.nutrition_plans FOR DELETE USING (true);

-- Events
CREATE POLICY events_select_policy ON public.events FOR SELECT USING (EXISTS (
  SELECT 1 FROM activities WHERE activities.id = events.activity_id AND activities.user_id = current_setting('app.user_id', true)
));
CREATE POLICY events_insert_policy ON public.events FOR INSERT WITH CHECK (EXISTS (
  SELECT 1 FROM activities WHERE activities.id = events.activity_id AND activities.user_id = current_setting('app.user_id', true)
));
CREATE POLICY events_update_policy ON public.events FOR UPDATE USING (EXISTS (
  SELECT 1 FROM activities WHERE activities.id = events.activity_id AND activities.user_id = current_setting('app.user_id', true)
));
CREATE POLICY events_delete_policy ON public.events FOR DELETE USING (EXISTS (
  SELECT 1 FROM activities WHERE activities.id = events.activity_id AND activities.user_id = current_setting('app.user_id', true)
));

-- Carb Loading Plans
CREATE POLICY carb_plans_select_policy ON public.carb_loading_plans FOR SELECT USING (user_id = current_setting('app.user_id', true));
CREATE POLICY carb_plans_insert_policy ON public.carb_loading_plans FOR INSERT WITH CHECK (user_id = current_setting('app.user_id', true));
CREATE POLICY carb_plans_update_policy ON public.carb_loading_plans FOR UPDATE USING (user_id = current_setting('app.user_id', true));
CREATE POLICY carb_plans_delete_policy ON public.carb_loading_plans FOR DELETE USING (user_id = current_setting('app.user_id', true));

-- Carb Loading Days
CREATE POLICY carb_days_select_policy ON public.carb_loading_days FOR SELECT USING (EXISTS (
  SELECT 1 FROM carb_loading_plans WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
  AND carb_loading_plans.user_id = current_setting('app.user_id', true)
));
CREATE POLICY carb_days_insert_policy ON public.carb_loading_days FOR INSERT WITH CHECK (EXISTS (
  SELECT 1 FROM carb_loading_plans WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
  AND carb_loading_plans.user_id = current_setting('app.user_id', true)
));
CREATE POLICY carb_days_update_policy ON public.carb_loading_days FOR UPDATE USING (EXISTS (
  SELECT 1 FROM carb_loading_plans WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
  AND carb_loading_plans.user_id = current_setting('app.user_id', true)
));
CREATE POLICY carb_days_delete_policy ON public.carb_loading_days FOR DELETE USING (EXISTS (
  SELECT 1 FROM carb_loading_plans WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
  AND carb_loading_plans.user_id = current_setting('app.user_id', true)
));

-- Activity Completions
CREATE POLICY activity_completions_select_policy ON public.activity_completions FOR SELECT USING (EXISTS (
  SELECT 1 FROM activities WHERE activities.id = activity_completions.activity_id
  AND activities.user_id = current_setting('app.user_id', true)
));
CREATE POLICY activity_completions_insert_policy ON public.activity_completions FOR INSERT WITH CHECK (EXISTS (
  SELECT 1 FROM activities WHERE activities.id = activity_completions.activity_id
  AND activities.user_id = current_setting('app.user_id', true)
));
CREATE POLICY activity_completions_update_policy ON public.activity_completions FOR UPDATE USING (EXISTS (
  SELECT 1 FROM activities WHERE activities.id = activity_completions.activity_id
  AND activities.user_id = current_setting('app.user_id', true)
));
CREATE POLICY activity_completions_delete_policy ON public.activity_completions FOR DELETE USING (EXISTS (
  SELECT 1 FROM activities WHERE activities.id = activity_completions.activity_id
  AND activities.user_id = current_setting('app.user_id', true)
));

-- Meal Types
CREATE POLICY meal_types_public_read ON public.meal_types FOR SELECT USING (true);

-- Carb Loading Foods
CREATE POLICY carb_loading_foods_public_read ON public.carb_loading_foods FOR SELECT USING (true);

-- Carb Loading User Foods
CREATE POLICY carb_loading_user_foods_device_read ON public.carb_loading_user_foods FOR SELECT USING (device_id = current_setting('app.device_id', true));
CREATE POLICY carb_loading_user_foods_device_insert ON public.carb_loading_user_foods FOR INSERT WITH CHECK (device_id = current_setting('app.device_id', true));
CREATE POLICY carb_loading_user_foods_device_update ON public.carb_loading_user_foods FOR UPDATE USING (device_id = current_setting('app.device_id', true));
CREATE POLICY carb_loading_user_foods_device_delete ON public.carb_loading_user_foods FOR DELETE USING (device_id = current_setting('app.device_id', true));

-- Food Meal Types
CREATE POLICY carb_loading_food_meal_types_public_read ON public.carb_loading_food_meal_types FOR SELECT USING (true);

-- User Food Meal Types
CREATE POLICY carb_loading_user_food_meal_types_device_read ON public.carb_loading_user_food_meal_types FOR SELECT USING (EXISTS (
  SELECT 1 FROM carb_loading_user_foods WHERE carb_loading_user_foods.id = carb_loading_user_food_meal_types.carb_loading_user_food_id
  AND carb_loading_user_foods.device_id = current_setting('app.device_id', true)
));
CREATE POLICY carb_loading_user_food_meal_types_device_insert ON public.carb_loading_user_food_meal_types FOR INSERT WITH CHECK (EXISTS (
  SELECT 1 FROM carb_loading_user_foods WHERE carb_loading_user_foods.id = carb_loading_user_food_meal_types.carb_loading_user_food_id
  AND carb_loading_user_foods.device_id = current_setting('app.device_id', true)
));
CREATE POLICY carb_loading_user_food_meal_types_device_delete ON public.carb_loading_user_food_meal_types FOR DELETE USING (EXISTS (
  SELECT 1 FROM carb_loading_user_foods WHERE carb_loading_user_foods.id = carb_loading_user_food_meal_types.carb_loading_user_food_id
  AND carb_loading_user_foods.device_id = current_setting('app.device_id', true)
));

-- Day Meals
CREATE POLICY carb_loading_day_meals_device_read ON public.carb_loading_day_meals FOR SELECT USING (EXISTS (
  SELECT 1 FROM carb_loading_days d JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
  WHERE d.id = carb_loading_day_meals.carb_loading_day_id AND p.user_id = current_setting('app.device_id', true)
));
CREATE POLICY carb_loading_day_meals_device_insert ON public.carb_loading_day_meals FOR INSERT WITH CHECK (EXISTS (
  SELECT 1 FROM carb_loading_days d JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
  WHERE d.id = carb_loading_day_meals.carb_loading_day_id AND p.user_id = current_setting('app.device_id', true)
));
CREATE POLICY carb_loading_day_meals_device_update ON public.carb_loading_day_meals FOR UPDATE USING (EXISTS (
  SELECT 1 FROM carb_loading_days d JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
  WHERE d.id = carb_loading_day_meals.carb_loading_day_id AND p.user_id = current_setting('app.device_id', true)
));
CREATE POLICY carb_loading_day_meals_device_delete ON public.carb_loading_day_meals FOR DELETE USING (EXISTS (
  SELECT 1 FROM carb_loading_days d JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
  WHERE d.id = carb_loading_day_meals.carb_loading_day_id AND p.user_id = current_setting('app.device_id', true)
));

-- Macro Targets
CREATE POLICY macro_targets_public_read ON public.macro_targets_table FOR SELECT USING (true);
CREATE POLICY macro_targets_authenticated_insert ON public.macro_targets_table FOR INSERT WITH CHECK (true);
CREATE POLICY macro_targets_authenticated_update ON public.macro_targets_table FOR UPDATE USING (true);

-- Workout Notes
CREATE POLICY workout_notes_user_read ON public.workout_notes FOR SELECT USING (user_id = (current_setting('app.user_id', true))::uuid);
CREATE POLICY workout_notes_user_insert ON public.workout_notes FOR INSERT WITH CHECK (user_id = (current_setting('app.user_id', true))::uuid);
CREATE POLICY workout_notes_user_update ON public.workout_notes FOR UPDATE USING (user_id = (current_setting('app.user_id', true))::uuid);
CREATE POLICY workout_notes_user_delete ON public.workout_notes FOR DELETE USING (user_id = (current_setting('app.user_id', true))::uuid);

-- ============================================================================
-- STEP 6: Grant permissions
-- ============================================================================

GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;

-- ============================================================================
-- STEP 7: Seed reference data
-- ============================================================================

-- Seed categories
INSERT INTO public.categories (id, name) VALUES
  (1, 'Fruits'),
  (2, 'Vegetables'),
  (3, 'Grains'),
  (4, 'Protein'),
  (5, 'Dairy'),
  (6, 'Snacks'),
  (7, 'Drinks'),
  (8, 'Sports Nutrition'),
  (9, 'Fast Carbs'),
  (10, 'Slow Carbs')
ON CONFLICT (id) DO NOTHING;

-- Seed meal types
INSERT INTO public.meal_types (id, name, display_name) VALUES
  (1, 'breakfast', 'Breakfast'),
  (2, 'lunch', 'Lunch'),
  (3, 'dinner', 'Dinner'),
  (5, 'morning_snack', 'Morning Snack'),
  (6, 'afternoon_snack', 'Afternoon Snack'),
  (7, 'evening_snack', 'Evening Snack')
ON CONFLICT (id) DO NOTHING;

-- Seed product types
INSERT INTO public.product_types (code, name, name_plural, sort_order) VALUES
  ('gel', 'Energy Gel', 'Energy Gels', 1),
  ('chew', 'Energy Chew', 'Energy Chews', 2),
  ('bar', 'Energy Bar', 'Energy Bars', 3),
  ('drink', 'Sports Drink', 'Sports Drinks', 4),
  ('food', 'Real Food', 'Real Foods', 5),
  ('electrolyte', 'Electrolyte', 'Electrolytes', 6)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- DONE!
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🎉 NUCLEAR OPTION COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Production database has been reset with DEV schema';
  RAISE NOTICE '';
  RAISE NOTICE 'Tables created: 26';
  RAISE NOTICE 'Reference data seeded: categories, meal_types, product_types';
  RAISE NOTICE '';
  RAISE NOTICE 'NEXT STEPS:';
  RAISE NOTICE '1. Seed foods table from your data source';
  RAISE NOTICE '2. Seed carb_loading_foods with default foods';
  RAISE NOTICE '3. Update edge functions to use new schema';
  RAISE NOTICE '4. Test activity/event creation';
  RAISE NOTICE '========================================';
END $$;
