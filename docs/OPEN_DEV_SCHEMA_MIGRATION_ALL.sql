DO $$ BEGIN
  CREATE TYPE gender_enum AS ENUM ('male','female','other','unknown');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE distance_unit_enum AS ENUM ('miles','kilometers');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE pace_unit_enum AS ENUM ('min_per_mile','min_per_km');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE gut_training_enum AS ENUM ('low','moderate','high');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE sport_enum AS ENUM ('running','cycling','swimming');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE activity_status_enum AS ENUM ('planned','in_progress','completed','skipped');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE intensity_enum AS ENUM ('easy','moderate','hard','race');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE cycling_terrain_enum AS ENUM ('flat','rolling','hilly');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE indoor_outdoor_enum AS ENUM ('indoor','outdoor');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE cycling_goal_enum AS ENUM ('endurance','tempo','intervals');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE plan_type_enum AS ENUM ('standard','carb_loading','recovery');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE category_enum AS ENUM ('before_run','during_run','after_run');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE public.users
  ALTER COLUMN gender TYPE gender_enum USING gender::gender_enum,
  ALTER COLUMN preferred_distance_unit TYPE distance_unit_enum USING preferred_distance_unit::distance_unit_enum,
  ALTER COLUMN preferred_pace_unit TYPE pace_unit_enum USING preferred_pace_unit::pace_unit_enum,
  ALTER COLUMN gut_training_level TYPE gut_training_enum USING gut_training_level::gut_training_enum;

ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.activities a
SET user_id = u.id
FROM public.users u
WHERE (a.user_id IS NOT NULL AND a.user_id ~ '^[0-9a-fA-F-]{8}-' AND a.user_id::uuid = u.id)
   OR (a.user_id IS NOT NULL AND a.user_id !~ '^[0-9a-fA-F-]{8}-' AND a.user_id = u.device_id);
ALTER TABLE public.activities ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.activities ADD CONSTRAINT activities_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.events e
SET user_id = u.id
FROM public.users u
WHERE (e.user_id IS NOT NULL AND e.user_id ~ '^[0-9a-fA-F-]{8}-' AND e.user_id::uuid = u.id)
   OR (e.user_id IS NOT NULL AND e.user_id !~ '^[0-9a-fA-F-]{8}-' AND e.user_id = u.device_id);
ALTER TABLE public.events ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.events ADD CONSTRAINT events_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.nutrition_plans ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.nutrition_plans np SET user_id = u.id FROM public.users u WHERE np.device_id = u.device_id AND np.device_id IS NOT NULL;
ALTER TABLE public.nutrition_plans ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.nutrition_plans ADD CONSTRAINT fk_np_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
ALTER TABLE public.nutrition_plans ALTER COLUMN plan_type TYPE plan_type_enum USING plan_type::plan_type_enum;

ALTER TABLE public.user_foods ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.user_foods uf SET user_id = u.id FROM public.users u WHERE uf.device_id = u.device_id AND uf.device_id IS NOT NULL;
ALTER TABLE public.user_foods ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.user_foods ADD CONSTRAINT fk_user_foods_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.carb_loading_user_foods ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.carb_loading_user_foods cf SET user_id = u.id FROM public.users u WHERE cf.device_id = u.device_id AND cf.device_id IS NOT NULL;
ALTER TABLE public.carb_loading_user_foods ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.carb_loading_user_foods ADD CONSTRAINT fk_cl_user_foods_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.carb_loading_plans ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.carb_loading_plans p SET user_id = u.id FROM public.users u WHERE p.user_id = u.device_id OR p.user_id = u.id::text;
ALTER TABLE public.carb_loading_plans ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE public.feature_survey_responses ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.feature_survey_responses fs SET user_id = u.id FROM public.users u WHERE fs.device_id = u.device_id AND fs.device_id IS NOT NULL;

ALTER TABLE public.activities
  ALTER COLUMN activity_type TYPE sport_enum USING activity_type::sport_enum,
  ALTER COLUMN status TYPE activity_status_enum USING status::activity_status_enum,
  ALTER COLUMN intensity_level TYPE intensity_enum USING intensity_level::intensity_enum,
  ALTER COLUMN cycling_terrain TYPE cycling_terrain_enum USING cycling_terrain::cycling_terrain_enum,
  ALTER COLUMN cycling_indoor_outdoor TYPE indoor_outdoor_enum USING cycling_indoor_outdoor::indoor_outdoor_enum,
  ALTER COLUMN cycling_session_goal TYPE cycling_goal_enum USING cycling_session_goal::cycling_goal_enum;

ALTER TABLE public.events
  ALTER COLUMN event_type TYPE text,
  ALTER COLUMN event_subtype TYPE text;

ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS categories category_enum[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS activity_types sport_enum[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_foods_categories_gin ON public.foods USING gin (categories);
CREATE INDEX IF NOT EXISTS idx_foods_activity_types_gin ON public.foods USING gin (activity_types);

ALTER TABLE public.user_foods
  ADD COLUMN IF NOT EXISTS categories category_enum[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS activity_types sport_enum[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_user_foods_categories_gin ON public.user_foods USING gin (categories);
CREATE INDEX IF NOT EXISTS idx_user_foods_activity_types_gin ON public.user_foods USING gin (activity_types);

ALTER TABLE public.foods DROP COLUMN IF EXISTS suitable_for_activities;
ALTER TABLE public.foods DROP COLUMN IF EXISTS cycling_suitable;
ALTER TABLE public.foods DROP COLUMN IF EXISTS swimming_suitable;
ALTER TABLE public.foods DROP COLUMN IF EXISTS before_run_suitable;
ALTER TABLE public.foods DROP COLUMN IF EXISTS during_run_suitable;
ALTER TABLE public.foods DROP COLUMN IF EXISTS after_run_suitable;
ALTER TABLE public.foods DROP COLUMN IF EXISTS run_portable;
ALTER TABLE public.foods DROP COLUMN IF EXISTS requires_preparation;
ALTER TABLE public.foods DROP COLUMN IF EXISTS aid_station_available;

ALTER TABLE public.user_foods DROP COLUMN IF EXISTS suitable_for_activities;

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS activity_id_new bigint;
UPDATE public.activities SET id = id;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS id_new bigint GENERATED BY DEFAULT AS IDENTITY;
UPDATE public.activities SET id_new = id_new WHERE id_new IS NULL;
UPDATE public.events e SET activity_id_new = a.id_new FROM public.activities a WHERE e.activity_id IS NOT NULL AND e.activity_id::text = a.id::text;
ALTER TABLE public.events DROP COLUMN IF EXISTS activity_id;
ALTER TABLE public.events RENAME COLUMN activity_id_new TO activity_id;
ALTER TABLE public.activities DROP CONSTRAINT IF EXISTS activities_pkey;
ALTER TABLE public.activities ADD CONSTRAINT activities_pkey PRIMARY KEY (id_new);
ALTER TABLE public.activities DROP COLUMN IF EXISTS id;
ALTER TABLE public.activities RENAME COLUMN id_new TO id;
ALTER TABLE public.events ADD CONSTRAINT events_activity_fk FOREIGN KEY (activity_id) REFERENCES public.activities(id);
CREATE INDEX IF NOT EXISTS idx_events_activity_id ON public.events(activity_id);

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS id_new bigint GENERATED BY DEFAULT AS IDENTITY;
UPDATE public.events SET id_new = id_new WHERE id_new IS NULL;
ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_pkey;
ALTER TABLE public.events ADD CONSTRAINT events_pkey PRIMARY KEY (id_new);
ALTER TABLE public.events DROP COLUMN IF EXISTS id;
ALTER TABLE public.events RENAME COLUMN id_new TO id;

ALTER TABLE public.carb_loading_plans ADD COLUMN IF NOT EXISTS id_new bigint GENERATED BY DEFAULT AS IDENTITY;
UPDATE public.carb_loading_plans SET id_new = id_new WHERE id_new IS NULL;
ALTER TABLE public.carb_loading_plans DROP CONSTRAINT IF EXISTS carb_loading_plans_pkey;
ALTER TABLE public.carb_loading_plans ADD CONSTRAINT carb_loading_plans_pkey PRIMARY KEY (id_new);

ALTER TABLE public.carb_loading_days ADD COLUMN IF NOT EXISTS carb_loading_plan_id_new bigint;
UPDATE public.carb_loading_days d SET carb_loading_plan_id_new = p.id_new FROM public.carb_loading_plans p WHERE d.carb_loading_plan_id = p.id;
ALTER TABLE public.carb_loading_days DROP COLUMN IF EXISTS carb_loading_plan_id;
ALTER TABLE public.carb_loading_days RENAME COLUMN carb_loading_plan_id_new TO carb_loading_plan_id;
ALTER TABLE public.carb_loading_days ADD CONSTRAINT cl_days_plan_fk FOREIGN KEY (carb_loading_plan_id) REFERENCES public.carb_loading_plans(id_new);

ALTER TABLE public.carb_loading_plans DROP COLUMN IF EXISTS id;
ALTER TABLE public.carb_loading_plans RENAME COLUMN id_new TO id;

ALTER TABLE public.carb_loading_days ADD COLUMN IF NOT EXISTS id_new bigint GENERATED BY DEFAULT AS IDENTITY;
UPDATE public.carb_loading_days SET id_new = id_new WHERE id_new IS NULL;
ALTER TABLE public.carb_loading_days DROP CONSTRAINT IF EXISTS carb_loading_days_pkey;
ALTER TABLE public.carb_loading_days ADD CONSTRAINT carb_loading_days_pkey PRIMARY KEY (id_new);
ALTER TABLE public.carb_loading_days DROP COLUMN IF EXISTS id;
ALTER TABLE public.carb_loading_days RENAME COLUMN id_new TO id;

ALTER TABLE public.workout_notes ADD COLUMN IF NOT EXISTS id_new bigint GENERATED BY DEFAULT AS IDENTITY;
UPDATE public.workout_notes SET id_new = id_new WHERE id_new IS NULL;
ALTER TABLE public.workout_notes DROP CONSTRAINT IF EXISTS workout_notes_pkey;
ALTER TABLE public.workout_notes ADD CONSTRAINT workout_notes_pkey PRIMARY KEY (id_new);
ALTER TABLE public.workout_notes DROP COLUMN IF EXISTS id;
ALTER TABLE public.workout_notes RENAME COLUMN id_new TO id;

ALTER TABLE public.feature_survey_responses ADD COLUMN IF NOT EXISTS id_new bigint GENERATED BY DEFAULT AS IDENTITY;
UPDATE public.feature_survey_responses SET id_new = id_new WHERE id_new IS NULL;
ALTER TABLE public.feature_survey_responses DROP CONSTRAINT IF EXISTS feature_survey_responses_pkey;
ALTER TABLE public.feature_survey_responses ADD CONSTRAINT feature_survey_responses_pkey PRIMARY KEY (id_new);
ALTER TABLE public.feature_survey_responses DROP COLUMN IF EXISTS id;
ALTER TABLE public.feature_survey_responses RENAME COLUMN id_new TO id;

DROP TABLE IF EXISTS public.activity_completions CASCADE;
DROP TABLE IF EXISTS public.edge_functions CASCADE;
DROP TABLE IF EXISTS public.food_categories CASCADE;
DROP TABLE IF EXISTS public.user_food_categories CASCADE;
DROP TABLE IF EXISTS public.carb_loading_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.carb_loading_user_food_meal_types CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.meal_types CASCADE;

ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_content DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.foods DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_foods DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_preferences DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.events DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_days DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_day_meals DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_notes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_foods DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_survey_responses DISABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO service_role;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO service_role;



ALTER TABLE public.feature_survey_responses ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.feature_survey_responses fs
SET user_id = u.id
FROM public.users u
WHERE fs.user_id IS NULL AND fs.device_id IS NOT NULL AND u.device_id = fs.device_id;

ALTER TABLE public.feature_survey_responses ALTER COLUMN user_id SET NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'feature_survey_responses'
      AND c.conname = 'unique_device_vote'
  ) THEN
    ALTER TABLE public.feature_survey_responses DROP CONSTRAINT unique_device_vote;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'feature_survey_responses'
      AND c.conname = 'unique_user_vote'
  ) THEN
    ALTER TABLE public.feature_survey_responses
      ADD CONSTRAINT unique_user_vote UNIQUE (user_id);
  END IF;
END$$;

DROP INDEX IF EXISTS idx_feature_survey_responses_device_id;
CREATE INDEX IF NOT EXISTS idx_feature_survey_responses_user_id ON public.feature_survey_responses (user_id);
CREATE INDEX IF NOT EXISTS idx_feature_survey_responses_voted_at ON public.feature_survey_responses (voted_at);

DROP TABLE IF EXISTS public.user_hidden_foods CASCADE;