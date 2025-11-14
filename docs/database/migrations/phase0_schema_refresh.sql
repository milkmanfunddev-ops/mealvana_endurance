-- Phase 0 Schema Refresh (data-preserving)
-- This script merges the intent of the earlier "Phase 0" destructive migration with the
-- ALTER-only approach while keeping existing production data intact.
-- Run inside Supabase SQL editor (DEV first, then PROD) with everything executed in one shot.
--
-- Key decisions encoded here:
--   * Canonical enums for users/activities/nutrition units replace TEXT+CHECK columns.
--   * Every user-scoped table backfills to users.id (UUID) and enforces cascading FKs.
--   * Legacy TEXT primary keys become BIGINT identity columns; dependent tables are rewired.
--   * foods/user_foods/carb-loading foods move to array columns; join tables are dropped after data backfill.
--   * RLS is disabled and grants are opened for faster iteration (DEV posture only).
--   * Feature/tracking tables such as feature_survey_responses/workout_notes stay but inherit the new PK/FK model.
--
-- After applying this migration you MUST:
--   1. Update Drift tables (`lib/shared/database/tables/*.dart`) to use `IntColumn` IDs and remove dropped tables.
--   2. Regenerate `app_database.g.dart` and the schema snapshot (`drift_dev schema dump ... database_schemas/v1/`).
--   3. Migrate Dart domain/repository code so activity/event/carb IDs are `int`, user IDs are UUID strings,
--      and array-backed fields (`categories`, `activityTypes`, `mealTypes`) flow through serialization.
--   4. Re-run integration tests and any sync logic that previously depended on device_id-based ownership.

BEGIN;

-- tighten transactional behaviour so we fail fast if something tries to hold locks too long
SET LOCAL lock_timeout = '5s';
SET LOCAL idle_in_transaction_session_timeout = '15min';

-------------------------------------------------------------------------------
-- Section 0: Helpers
-------------------------------------------------------------------------------
-- materialise a lightweight lookup of user ids/device ids so we do not keep
-- re-scanning the users table while backfilling UUID foreign keys.
DROP TABLE IF EXISTS tmp_user_lookup;
CREATE TEMP TABLE tmp_user_lookup AS
SELECT id        AS user_id,
       device_id AS device_id
FROM public.users;
CREATE UNIQUE INDEX ON tmp_user_lookup (user_id);
CREATE UNIQUE INDEX ON tmp_user_lookup (device_id);

-------------------------------------------------------------------------------
-- Section 1: Enumerations and canonical types
-------------------------------------------------------------------------------
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
  CREATE TYPE category_enum AS ENUM ('before_run','during_run','after_run');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE plan_type_enum AS ENUM ('standard','carb_loading','recovery');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_gender_check,
  DROP CONSTRAINT IF EXISTS users_preferred_distance_unit_check,
  DROP CONSTRAINT IF EXISTS users_preferred_pace_unit_check,
  DROP CONSTRAINT IF EXISTS users_gut_training_level_check;

ALTER TABLE public.users
  ALTER COLUMN preferred_distance_unit DROP DEFAULT,
  ALTER COLUMN preferred_pace_unit     DROP DEFAULT,
  ALTER COLUMN gut_training_level      DROP DEFAULT;

ALTER TABLE public.users
  ALTER COLUMN gender                  TYPE gender_enum        USING NULLIF(gender,'')::gender_enum,
  ALTER COLUMN preferred_distance_unit TYPE distance_unit_enum USING preferred_distance_unit::distance_unit_enum,
  ALTER COLUMN preferred_pace_unit     TYPE pace_unit_enum     USING preferred_pace_unit::pace_unit_enum,
  ALTER COLUMN gut_training_level      TYPE gut_training_enum  USING gut_training_level::gut_training_enum;

ALTER TABLE public.users
  ALTER COLUMN preferred_distance_unit SET DEFAULT 'miles'::distance_unit_enum,
  ALTER COLUMN preferred_pace_unit     SET DEFAULT 'min_per_mile'::pace_unit_enum,
  ALTER COLUMN gut_training_level      SET DEFAULT 'moderate'::gut_training_enum;

ALTER TABLE public.nutrition_plans
  DROP CONSTRAINT IF EXISTS nutrition_plans_plan_type_check,
  ALTER COLUMN plan_type DROP DEFAULT;

ALTER TABLE public.nutrition_plans
  ALTER COLUMN plan_type TYPE plan_type_enum USING plan_type::plan_type_enum;

ALTER TABLE public.nutrition_plans
  ALTER COLUMN plan_type SET DEFAULT 'standard'::plan_type_enum;

-------------------------------------------------------------------------------
-- Section 2: Foods + carb-loading catalogs → arrays (preserve associations)
-------------------------------------------------------------------------------
-- foods: categories & sport suitability
ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS categories     category_enum[] NOT NULL DEFAULT '{}'::category_enum[],
  ADD COLUMN IF NOT EXISTS activity_types sport_enum[]    NOT NULL DEFAULT '{}'::sport_enum[];

-- user foods retain arrays (even though we do not need to preserve existing data)
ALTER TABLE public.user_foods
  ADD COLUMN IF NOT EXISTS categories     category_enum[] NOT NULL DEFAULT '{}'::category_enum[],
  ADD COLUMN IF NOT EXISTS activity_types sport_enum[]    NOT NULL DEFAULT '{}'::sport_enum[];

-- carb loading base/user foods get meal type arrays
ALTER TABLE public.carb_loading_foods
  ADD COLUMN IF NOT EXISTS meal_types text[] NOT NULL DEFAULT '{}'::text[];
ALTER TABLE public.carb_loading_user_foods
  ADD COLUMN IF NOT EXISTS meal_types text[] NOT NULL DEFAULT '{}'::text[];

-- carb loading day meals get an inline text label so we can drop the FK to meal_types
ALTER TABLE public.carb_loading_day_meals
  ADD COLUMN IF NOT EXISTS meal_type text;

-- backfill food categories from the legacy join table
WITH category_map AS (
  SELECT c.id,
         CASE lower(replace(trim(c.name), ' ', '_'))
           WHEN 'before_run' THEN 'before_run'::category_enum
           WHEN 'during_run' THEN 'during_run'::category_enum
           WHEN 'after_run'  THEN 'after_run'::category_enum
         END AS enum_value
  FROM public.categories c
),
food_category_agg AS (
  SELECT fc.food_id,
         array_agg(DISTINCT cm.enum_value ORDER BY cm.enum_value) AS cats
  FROM public.food_categories fc
  JOIN category_map cm ON cm.id = fc.category_id AND cm.enum_value IS NOT NULL
  GROUP BY fc.food_id
)
UPDATE public.foods f
SET categories = COALESCE(fca.cats, '{}'::category_enum[])
FROM food_category_agg fca
WHERE f.id = fca.food_id;

-- derive sport suitability from the legacy JSON map (when present)
WITH activity_flags AS (
  SELECT f.id,
         COALESCE(
           (
             SELECT COALESCE(array_agg(DISTINCT
               CASE lower(j.key)
                 WHEN 'running' THEN 'running'::sport_enum
                 WHEN 'cycling' THEN 'cycling'::sport_enum
                 WHEN 'swimming' THEN 'swimming'::sport_enum
               END
             ) FILTER (WHERE lower(j.value) = 'true' AND lower(j.key) IN ('running','cycling','swimming')),
             ARRAY[]::sport_enum[])
             FROM jsonb_each_text(COALESCE(f.suitable_for_activities, '{}'::jsonb)) AS j(key, value)
           ),
           ARRAY[]::sport_enum[]
         ) AS sports
  FROM public.foods f
)
UPDATE public.foods f
SET activity_types = af.sports
FROM activity_flags af
WHERE f.id = af.id;

-- backfill carb loading meal types for default foods
WITH meal_name_map AS (
  SELECT mt.id, mt.name
  FROM public.meal_types mt
),
carb_food_meal_types AS (
  SELECT cfmt.carb_loading_food_id AS food_id,
         array_agg(DISTINCT mnm.name ORDER BY mnm.name) AS meal_types
  FROM public.carb_loading_food_meal_types cfmt
  JOIN meal_name_map mnm ON mnm.id = cfmt.meal_type_id
  GROUP BY cfmt.carb_loading_food_id
)
UPDATE public.carb_loading_foods cf
SET meal_types = COALESCE(cfmt.meal_types, '{}'::text[])
FROM carb_food_meal_types cfmt
WHERE cf.id = cfmt.food_id;

-- copy the human-readable meal type name directly onto carb_loading_day_meals
UPDATE public.carb_loading_day_meals cldm
SET meal_type = mnm.name
FROM public.meal_types mnm
WHERE cldm.meal_type IS NULL AND mnm.id = cldm.meal_type_id;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.carb_loading_day_meals WHERE meal_type IS NULL) THEN
    RAISE EXCEPTION 'Unable to resolve meal_type text for every carb_loading_day_meals row.';
  END IF;
END$$;

ALTER TABLE public.carb_loading_day_meals
  ALTER COLUMN meal_type SET NOT NULL;

DROP INDEX IF EXISTS idx_carb_day_meals_meal_type;
ALTER TABLE public.carb_loading_day_meals DROP COLUMN IF EXISTS meal_type_id;
CREATE INDEX idx_carb_day_meals_meal_type ON public.carb_loading_day_meals (meal_type);

-------------------------------------------------------------------------------
-- Section 2a: Product types → enum
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
-- Section 3: Standardise user ownership (UUID foreign keys everywhere)
-------------------------------------------------------------------------------
-- helper regexp literal for UUID detection
-- NOTE: repeated inline because psql DO blocks cannot share variables easily.

-- activities.user_id (text -> uuid)
DROP POLICY IF EXISTS activities_select_policy ON public.activities;
DROP POLICY IF EXISTS activities_insert_policy ON public.activities;
DROP POLICY IF EXISTS activities_update_policy ON public.activities;
DROP POLICY IF EXISTS activities_delete_policy ON public.activities;
DROP POLICY IF EXISTS events_select_policy ON public.events;
DROP POLICY IF EXISTS events_insert_policy ON public.events;
DROP POLICY IF EXISTS events_update_policy ON public.events;
DROP POLICY IF EXISTS events_delete_policy ON public.events;
DROP POLICY IF EXISTS activity_completions_select_policy ON public.activity_completions;
DROP POLICY IF EXISTS activity_completions_insert_policy ON public.activity_completions;
DROP POLICY IF EXISTS activity_completions_update_policy ON public.activity_completions;
DROP POLICY IF EXISTS activity_completions_delete_policy ON public.activity_completions;

ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
UPDATE public.activities a
SET user_id_uuid = u.user_id
FROM tmp_user_lookup u
WHERE a.user_id_uuid IS DISTINCT FROM u.user_id
  AND (
        (a.user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND u.user_id = a.user_id::uuid)
     OR (a.user_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND u.device_id = a.user_id)
      );
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.activities WHERE user_id_uuid IS NULL) THEN
    RAISE EXCEPTION 'activities.user_id could not be mapped to users.id. Fix data before rerunning.';
  END IF;
END$$;
ALTER TABLE public.activities DROP CONSTRAINT IF EXISTS activities_user_id_fkey;
ALTER TABLE public.activities DROP COLUMN user_id;
ALTER TABLE public.activities RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE public.activities ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.activities ADD CONSTRAINT activities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activity_type_check,
  DROP CONSTRAINT IF EXISTS status_check,
  DROP CONSTRAINT IF EXISTS intensity_check,
  DROP CONSTRAINT IF EXISTS activities_cycling_terrain_check,
  DROP CONSTRAINT IF EXISTS activities_cycling_indoor_outdoor_check,
  DROP CONSTRAINT IF EXISTS activities_cycling_session_goal_check,
  DROP CONSTRAINT IF EXISTS activities_sport_type_check,
  DROP CONSTRAINT IF EXISTS activities_cycling_columns_check,
  DROP CONSTRAINT IF EXISTS activities_swimming_columns_check;

ALTER TABLE public.activities
  ALTER COLUMN status     DROP DEFAULT,
  ALTER COLUMN sport_type DROP DEFAULT;

ALTER TABLE public.activities
  ALTER COLUMN activity_type          TYPE sport_enum           USING activity_type::sport_enum,
  ALTER COLUMN status                 TYPE activity_status_enum USING status::activity_status_enum,
  ALTER COLUMN intensity_level        TYPE intensity_enum       USING NULLIF(intensity_level,'')::intensity_enum,
  ALTER COLUMN cycling_terrain        TYPE cycling_terrain_enum USING NULLIF(cycling_terrain,'')::cycling_terrain_enum,
  ALTER COLUMN cycling_indoor_outdoor TYPE indoor_outdoor_enum  USING NULLIF(cycling_indoor_outdoor,'')::indoor_outdoor_enum,
  ALTER COLUMN cycling_session_goal   TYPE cycling_goal_enum    USING NULLIF(cycling_session_goal,'')::cycling_goal_enum,
  ALTER COLUMN sport_type             TYPE sport_enum           USING sport_type::sport_enum;

ALTER TABLE public.activities
  ALTER COLUMN status     SET DEFAULT 'planned'::activity_status_enum,
  ALTER COLUMN sport_type SET DEFAULT 'running'::sport_enum;

-- events.user_id
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
UPDATE public.events e
SET user_id_uuid = u.user_id
FROM tmp_user_lookup u
WHERE e.user_id_uuid IS DISTINCT FROM u.user_id
  AND (
        (e.user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND u.user_id = e.user_id::uuid)
     OR (e.user_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND u.device_id = e.user_id)
      );
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.events WHERE user_id_uuid IS NULL) THEN
    RAISE EXCEPTION 'events.user_id could not be mapped to users.id. Fix data before rerunning.';
  END IF;
END$$;
ALTER TABLE public.events DROP COLUMN user_id;
ALTER TABLE public.events RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE public.events ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.events ADD CONSTRAINT events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- nutrition_plans.user_id (new column alongside legacy device_id)
ALTER TABLE public.nutrition_plans ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.nutrition_plans np
SET user_id = u.user_id
FROM tmp_user_lookup u
WHERE np.user_id IS DISTINCT FROM u.user_id AND u.device_id = np.device_id;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.nutrition_plans WHERE user_id IS NULL) THEN
    RAISE EXCEPTION 'nutrition_plans.user_id missing (device_id not found in users).';
  END IF;
END$$;
ALTER TABLE public.nutrition_plans ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.nutrition_plans DROP CONSTRAINT IF EXISTS fk_np_user;
ALTER TABLE public.nutrition_plans ADD CONSTRAINT fk_np_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- user_foods: keep device_id for now but add canonical uuid
ALTER TABLE public.user_foods ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.user_foods uf
SET user_id = u.user_id
FROM tmp_user_lookup u
WHERE uf.user_id IS DISTINCT FROM u.user_id AND u.device_id = uf.device_id;
ALTER TABLE public.user_foods ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.user_foods ADD CONSTRAINT fk_user_foods_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- user_hidden_foods
ALTER TABLE public.user_hidden_foods ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.user_hidden_foods uhf
SET user_id = u.user_id
FROM tmp_user_lookup u
WHERE uhf.user_id IS DISTINCT FROM u.user_id AND u.device_id = uhf.device_id;
ALTER TABLE public.user_hidden_foods ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.user_hidden_foods ADD CONSTRAINT fk_user_hidden_foods_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- carb_loading_user_foods
ALTER TABLE public.carb_loading_user_foods ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.carb_loading_user_foods cuf
SET user_id = u.user_id
FROM tmp_user_lookup u
WHERE cuf.user_id IS DISTINCT FROM u.user_id AND u.device_id = cuf.device_id;
ALTER TABLE public.carb_loading_user_foods ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.carb_loading_user_foods ADD CONSTRAINT fk_carb_loading_user_foods_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- carb_loading_plans
DROP POLICY IF EXISTS carb_plans_select_policy ON public.carb_loading_plans;
DROP POLICY IF EXISTS carb_plans_insert_policy ON public.carb_loading_plans;
DROP POLICY IF EXISTS carb_plans_update_policy ON public.carb_loading_plans;
DROP POLICY IF EXISTS carb_plans_delete_policy ON public.carb_loading_plans;
DROP POLICY IF EXISTS carb_days_select_policy ON public.carb_loading_days;
DROP POLICY IF EXISTS carb_days_insert_policy ON public.carb_loading_days;
DROP POLICY IF EXISTS carb_days_update_policy ON public.carb_loading_days;
DROP POLICY IF EXISTS carb_days_delete_policy ON public.carb_loading_days;
DROP POLICY IF EXISTS carb_loading_day_meals_device_read ON public.carb_loading_day_meals;
DROP POLICY IF EXISTS carb_loading_day_meals_device_insert ON public.carb_loading_day_meals;
DROP POLICY IF EXISTS carb_loading_day_meals_device_update ON public.carb_loading_day_meals;
DROP POLICY IF EXISTS carb_loading_day_meals_device_delete ON public.carb_loading_day_meals;

ALTER TABLE public.carb_loading_plans ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
UPDATE public.carb_loading_plans p
SET user_id_uuid = u.user_id
FROM tmp_user_lookup u
WHERE p.user_id_uuid IS DISTINCT FROM u.user_id
  AND (
        (p.user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND u.user_id = p.user_id::uuid)
     OR (p.user_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND u.device_id = p.user_id)
      );
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.carb_loading_plans WHERE user_id_uuid IS NULL) THEN
    RAISE EXCEPTION 'carb_loading_plans.user_id could not be mapped to users.id.';
  END IF;
END$$;
ALTER TABLE public.carb_loading_plans DROP COLUMN user_id;
ALTER TABLE public.carb_loading_plans RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE public.carb_loading_plans ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.carb_loading_plans ADD CONSTRAINT fk_carb_loading_plans_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- carb_loading_day_meals policies reference device_id indirectly; disabling RLS later keeps them from breaking.

-------------------------------------------------------------------------------
-- Section 4: Convert text primary keys to bigint identities (activities → events → carb loading)
-------------------------------------------------------------------------------
-- Drop dependent indexes up-front (they will be recreated later with the same names)
DROP INDEX IF EXISTS idx_events_activity;
DROP INDEX IF EXISTS idx_nutrition_plans_activity_id;
DROP INDEX IF EXISTS idx_carb_plans_event;
DROP INDEX IF EXISTS idx_carb_days_plan;
DROP INDEX IF EXISTS idx_carb_day_meals_day;

-- ACTIVITIES ---------------------------------------------------------------
CREATE TEMP TABLE tmp_activity_ids AS
SELECT a.id              AS legacy_id,
       row_number() OVER (ORDER BY a.created_at NULLS FIRST, a.updated_at NULLS FIRST, a.id) AS new_id
FROM public.activities a;

ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS id_new bigint;
UPDATE public.activities a
SET id_new = m.new_id
FROM tmp_activity_ids m
WHERE a.id = m.legacy_id;

ALTER TABLE public.activities ALTER COLUMN id_new SET NOT NULL;

DROP SEQUENCE IF EXISTS public.activities_id_seq;
CREATE SEQUENCE public.activities_id_seq OWNED BY public.activities.id_new;
SELECT setval('public.activities_id_seq', (SELECT max(new_id) FROM tmp_activity_ids));
ALTER TABLE public.activities ALTER COLUMN id_new SET DEFAULT nextval('public.activities_id_seq');
ALTER TABLE public.activities ADD CONSTRAINT activities_id_new_unique UNIQUE (id_new);

-- update referencing tables (events + nutrition_plans)
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS activity_id_new bigint;
UPDATE public.events e
SET activity_id_new = m.new_id
FROM tmp_activity_ids m
WHERE e.activity_id = m.legacy_id;

ALTER TABLE public.nutrition_plans ADD COLUMN IF NOT EXISTS activity_id_new bigint;
UPDATE public.nutrition_plans np
SET activity_id_new = m.new_id
FROM tmp_activity_ids m
WHERE np.activity_id = m.legacy_id;

ALTER TABLE public.activity_completions ADD COLUMN IF NOT EXISTS activity_id_new bigint;
UPDATE public.activity_completions ac
SET activity_id_new = m.new_id
FROM tmp_activity_ids m
WHERE ac.activity_id = m.legacy_id;

ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_activity_id_fkey;
ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_activity_id_key;
ALTER TABLE public.nutrition_plans DROP CONSTRAINT IF EXISTS fk_nutrition_plans_activity_id;
ALTER TABLE public.activity_completions DROP CONSTRAINT IF EXISTS activity_completions_activity_id_fkey;

ALTER TABLE public.events DROP COLUMN IF EXISTS activity_id;
ALTER TABLE public.events RENAME COLUMN activity_id_new TO activity_id;
ALTER TABLE public.events ALTER COLUMN activity_id DROP NOT NULL;
ALTER TABLE public.events ADD CONSTRAINT events_activity_fkey FOREIGN KEY (activity_id) REFERENCES public.activities(id_new) ON DELETE SET NULL;

ALTER TABLE public.nutrition_plans DROP COLUMN IF EXISTS activity_id;
ALTER TABLE public.nutrition_plans RENAME COLUMN activity_id_new TO activity_id;
ALTER TABLE public.nutrition_plans ADD CONSTRAINT fk_nutrition_plans_activity_id FOREIGN KEY (activity_id) REFERENCES public.activities(id_new) ON DELETE SET NULL;

ALTER TABLE public.activity_completions DROP COLUMN IF EXISTS activity_id;
ALTER TABLE public.activity_completions RENAME COLUMN activity_id_new TO activity_id;
ALTER TABLE public.activity_completions ADD CONSTRAINT activity_completions_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.activities(id_new) ON DELETE CASCADE;
ALTER TABLE public.activity_completions ADD CONSTRAINT activity_completions_activity_id_key UNIQUE (activity_id);

ALTER TABLE public.activities DROP CONSTRAINT IF EXISTS activities_pkey;
ALTER TABLE public.activities DROP COLUMN IF EXISTS id;
ALTER TABLE public.activities RENAME COLUMN id_new TO id;
ALTER TABLE public.activities ADD CONSTRAINT activities_pkey PRIMARY KEY (id);

-- EVENTS ------------------------------------------------------------------
CREATE TEMP TABLE tmp_event_ids AS
SELECT e.id              AS legacy_id,
       row_number() OVER (ORDER BY e.created_at NULLS FIRST, e.id) AS new_id
FROM public.events e;

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS id_new bigint;
UPDATE public.events e
SET id_new = m.new_id
FROM tmp_event_ids m
WHERE e.id = m.legacy_id;
ALTER TABLE public.events ALTER COLUMN id_new SET NOT NULL;

DROP SEQUENCE IF EXISTS public.events_id_seq;
CREATE SEQUENCE public.events_id_seq OWNED BY public.events.id_new;
SELECT setval('public.events_id_seq', (SELECT max(new_id) FROM tmp_event_ids));
ALTER TABLE public.events ALTER COLUMN id_new SET DEFAULT nextval('public.events_id_seq');
ALTER TABLE public.events ADD CONSTRAINT events_id_new_unique UNIQUE (id_new);

ALTER TABLE public.carb_loading_plans ADD COLUMN IF NOT EXISTS event_id_new bigint;
UPDATE public.carb_loading_plans cp
SET event_id_new = m.new_id
FROM tmp_event_ids m
WHERE cp.event_id = m.legacy_id;

ALTER TABLE public.carb_loading_plans DROP CONSTRAINT IF EXISTS carb_loading_plans_event_id_fkey;
ALTER TABLE public.carb_loading_plans DROP COLUMN IF EXISTS event_id;
ALTER TABLE public.carb_loading_plans RENAME COLUMN event_id_new TO event_id;
ALTER TABLE public.carb_loading_plans ADD CONSTRAINT carb_loading_plans_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id_new) ON DELETE CASCADE;

ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_pkey;
ALTER TABLE public.events DROP COLUMN IF EXISTS id;
ALTER TABLE public.events RENAME COLUMN id_new TO id;
ALTER TABLE public.events ADD CONSTRAINT events_pkey PRIMARY KEY (id);

-- CARB LOADING PLANS ------------------------------------------------------
CREATE TEMP TABLE tmp_carb_loading_plan_ids AS
SELECT p.id AS legacy_id,
       row_number() OVER (ORDER BY p.generated_at NULLS FIRST, p.start_date NULLS FIRST, p.id) AS new_id
FROM public.carb_loading_plans p;

ALTER TABLE public.carb_loading_plans ADD COLUMN IF NOT EXISTS id_new bigint;
UPDATE public.carb_loading_plans p
SET id_new = m.new_id
FROM tmp_carb_loading_plan_ids m
WHERE p.id = m.legacy_id;
ALTER TABLE public.carb_loading_plans ALTER COLUMN id_new SET NOT NULL;

DROP SEQUENCE IF EXISTS public.carb_loading_plans_id_seq;
CREATE SEQUENCE public.carb_loading_plans_id_seq OWNED BY public.carb_loading_plans.id_new;
SELECT setval('public.carb_loading_plans_id_seq', (SELECT max(new_id) FROM tmp_carb_loading_plan_ids));
ALTER TABLE public.carb_loading_plans ALTER COLUMN id_new SET DEFAULT nextval('public.carb_loading_plans_id_seq');
ALTER TABLE public.carb_loading_plans ADD CONSTRAINT carb_loading_plans_id_new_unique UNIQUE (id_new);

ALTER TABLE public.carb_loading_days ADD COLUMN IF NOT EXISTS carb_loading_plan_id_new bigint;
UPDATE public.carb_loading_days d
SET carb_loading_plan_id_new = m.new_id
FROM tmp_carb_loading_plan_ids m
WHERE d.carb_loading_plan_id = m.legacy_id;

ALTER TABLE public.carb_loading_day_meals ADD COLUMN IF NOT EXISTS carb_loading_plan_id_new bigint;
UPDATE public.carb_loading_day_meals mls
SET carb_loading_plan_id_new = m.new_id
FROM tmp_carb_loading_plan_ids m,
     public.carb_loading_days d
WHERE d.id = mls.carb_loading_day_id
  AND d.carb_loading_plan_id = m.legacy_id;

ALTER TABLE public.carb_loading_days DROP CONSTRAINT IF EXISTS carb_loading_days_carb_loading_plan_id_fkey;
ALTER TABLE public.carb_loading_day_meals DROP CONSTRAINT IF EXISTS carb_loading_day_meals_plan_fk;

ALTER TABLE public.carb_loading_days DROP COLUMN IF EXISTS carb_loading_plan_id;
ALTER TABLE public.carb_loading_days RENAME COLUMN carb_loading_plan_id_new TO carb_loading_plan_id;
ALTER TABLE public.carb_loading_days ADD CONSTRAINT carb_loading_days_plan_fk FOREIGN KEY (carb_loading_plan_id) REFERENCES public.carb_loading_plans(id_new) ON DELETE CASCADE;

ALTER TABLE public.carb_loading_day_meals DROP COLUMN IF EXISTS carb_loading_plan_id;
ALTER TABLE public.carb_loading_day_meals RENAME COLUMN carb_loading_plan_id_new TO carb_loading_plan_id;
ALTER TABLE public.carb_loading_day_meals ADD CONSTRAINT carb_loading_day_meals_plan_fk FOREIGN KEY (carb_loading_plan_id) REFERENCES public.carb_loading_plans(id_new) ON DELETE CASCADE;
ALTER TABLE public.carb_loading_day_meals ALTER COLUMN carb_loading_plan_id SET NOT NULL;

ALTER TABLE public.carb_loading_plans DROP CONSTRAINT IF EXISTS carb_loading_plans_pkey;
ALTER TABLE public.carb_loading_plans DROP COLUMN IF EXISTS id;
ALTER TABLE public.carb_loading_plans RENAME COLUMN id_new TO id;
ALTER TABLE public.carb_loading_plans ADD CONSTRAINT carb_loading_plans_pkey PRIMARY KEY (id);

-- CARB LOADING DAYS -------------------------------------------------------
CREATE TEMP TABLE tmp_carb_loading_day_ids AS
SELECT d.id AS legacy_id,
       row_number() OVER (ORDER BY d.plan_date NULLS FIRST, d.id) AS new_id
FROM public.carb_loading_days d;

ALTER TABLE public.carb_loading_days ADD COLUMN IF NOT EXISTS id_new bigint;
UPDATE public.carb_loading_days d
SET id_new = m.new_id
FROM tmp_carb_loading_day_ids m
WHERE d.id = m.legacy_id;
ALTER TABLE public.carb_loading_days ALTER COLUMN id_new SET NOT NULL;

DROP SEQUENCE IF EXISTS public.carb_loading_days_id_seq;
CREATE SEQUENCE public.carb_loading_days_id_seq OWNED BY public.carb_loading_days.id_new;
SELECT setval('public.carb_loading_days_id_seq', (SELECT max(new_id) FROM tmp_carb_loading_day_ids));
ALTER TABLE public.carb_loading_days ALTER COLUMN id_new SET DEFAULT nextval('public.carb_loading_days_id_seq');
ALTER TABLE public.carb_loading_days ADD CONSTRAINT carb_loading_days_id_new_unique UNIQUE (id_new);

ALTER TABLE public.carb_loading_day_meals ADD COLUMN IF NOT EXISTS carb_loading_day_id_new bigint;
UPDATE public.carb_loading_day_meals mls
SET carb_loading_day_id_new = m.new_id
FROM tmp_carb_loading_day_ids m
WHERE mls.carb_loading_day_id = m.legacy_id;

ALTER TABLE public.carb_loading_day_meals DROP CONSTRAINT IF EXISTS carb_loading_day_meals_carb_loading_day_id_fkey;
ALTER TABLE public.carb_loading_day_meals DROP COLUMN IF EXISTS carb_loading_day_id;
ALTER TABLE public.carb_loading_day_meals RENAME COLUMN carb_loading_day_id_new TO carb_loading_day_id;
ALTER TABLE public.carb_loading_day_meals ADD CONSTRAINT carb_loading_day_meals_carb_loading_day_id_fkey FOREIGN KEY (carb_loading_day_id) REFERENCES public.carb_loading_days(id_new) ON DELETE CASCADE;

ALTER TABLE public.carb_loading_days DROP CONSTRAINT IF EXISTS carb_loading_days_pkey;
ALTER TABLE public.carb_loading_days DROP COLUMN IF EXISTS id;
ALTER TABLE public.carb_loading_days RENAME COLUMN id_new TO id;
ALTER TABLE public.carb_loading_days ADD CONSTRAINT carb_loading_days_pkey PRIMARY KEY (id);

-- WORKOUT NOTES -----------------------------------------------------------
CREATE TEMP TABLE tmp_workout_note_ids AS
SELECT wn.id AS legacy_id,
       row_number() OVER (ORDER BY wn.created_at NULLS FIRST, wn.id) AS new_id
FROM public.workout_notes wn;

ALTER TABLE public.workout_notes ADD COLUMN IF NOT EXISTS id_new bigint;
UPDATE public.workout_notes wn
SET id_new = m.new_id
FROM tmp_workout_note_ids m
WHERE wn.id = m.legacy_id;
ALTER TABLE public.workout_notes ALTER COLUMN id_new SET NOT NULL;

DROP SEQUENCE IF EXISTS public.workout_notes_id_seq;
CREATE SEQUENCE public.workout_notes_id_seq OWNED BY public.workout_notes.id_new;
SELECT setval('public.workout_notes_id_seq', (SELECT max(new_id) FROM tmp_workout_note_ids));
ALTER TABLE public.workout_notes ALTER COLUMN id_new SET DEFAULT nextval('public.workout_notes_id_seq');

ALTER TABLE public.workout_notes DROP CONSTRAINT IF EXISTS workout_notes_pkey;
ALTER TABLE public.workout_notes DROP COLUMN IF EXISTS id;
ALTER TABLE public.workout_notes RENAME COLUMN id_new TO id;
ALTER TABLE public.workout_notes ADD CONSTRAINT workout_notes_pkey PRIMARY KEY (id);

-------------------------------------------------------------------------------
-- Section 4a: Feature survey responses ownership & IDs
-------------------------------------------------------------------------------

ALTER TABLE public.feature_survey_responses ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.feature_survey_responses fs
SET user_id = u.user_id
FROM tmp_user_lookup u
WHERE fs.user_id IS DISTINCT FROM u.user_id AND u.device_id = fs.device_id;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.feature_survey_responses WHERE user_id IS NULL) THEN
    RAISE EXCEPTION 'feature_survey_responses.user_id could not be backfilled from users';
  END IF;
END$$;

ALTER TABLE public.feature_survey_responses ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.feature_survey_responses DROP CONSTRAINT IF EXISTS feature_survey_responses_device_id_fkey;
ALTER TABLE public.feature_survey_responses ADD CONSTRAINT feature_survey_responses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.feature_survey_responses ADD COLUMN IF NOT EXISTS id_new bigint;
DROP SEQUENCE IF EXISTS public.feature_survey_responses_id_seq;
CREATE SEQUENCE public.feature_survey_responses_id_seq OWNED BY public.feature_survey_responses.id_new;
UPDATE public.feature_survey_responses
SET id_new = nextval('public.feature_survey_responses_id_seq')
WHERE id_new IS NULL;
ALTER TABLE public.feature_survey_responses ALTER COLUMN id_new SET NOT NULL;
ALTER TABLE public.feature_survey_responses ALTER COLUMN id_new SET DEFAULT nextval('public.feature_survey_responses_id_seq');

ALTER TABLE public.feature_survey_responses DROP CONSTRAINT IF EXISTS feature_survey_responses_pkey;
ALTER TABLE public.feature_survey_responses ADD CONSTRAINT feature_survey_responses_pkey PRIMARY KEY (id_new);
ALTER TABLE public.feature_survey_responses DROP COLUMN IF EXISTS id;
ALTER TABLE public.feature_survey_responses RENAME COLUMN id_new TO id;
ALTER SEQUENCE public.feature_survey_responses_id_seq OWNED BY public.feature_survey_responses.id;

ALTER TABLE public.feature_survey_responses DROP CONSTRAINT IF EXISTS unique_device_vote;
ALTER TABLE public.feature_survey_responses DROP CONSTRAINT IF EXISTS unique_user_vote;
ALTER TABLE public.feature_survey_responses ADD CONSTRAINT unique_user_vote UNIQUE (user_id);

DROP INDEX IF EXISTS idx_feature_survey_responses_device_id;
CREATE INDEX IF NOT EXISTS idx_feature_survey_responses_user_id ON public.feature_survey_responses (user_id);
CREATE INDEX IF NOT EXISTS idx_feature_survey_responses_voted_at ON public.feature_survey_responses (voted_at);

ALTER TABLE public.feature_survey_responses DROP COLUMN IF EXISTS device_id;

-------------------------------------------------------------------------------
-- Section 4b: Food preferences ownership
-------------------------------------------------------------------------------

ALTER TABLE public.food_preferences ADD COLUMN IF NOT EXISTS user_id uuid;
UPDATE public.food_preferences fp
SET user_id = u.user_id
FROM tmp_user_lookup u
WHERE fp.user_id IS DISTINCT FROM u.user_id AND u.device_id = fp.device_id;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.food_preferences WHERE user_id IS NULL) THEN
    RAISE EXCEPTION 'food_preferences.user_id could not be backfilled from users';
  END IF;
END$$;

ALTER TABLE public.food_preferences ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.food_preferences DROP CONSTRAINT IF EXISTS food_preferences_device_id_fkey;
ALTER TABLE public.food_preferences ADD CONSTRAINT food_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

DROP INDEX IF EXISTS idx_food_preferences_device_food;
DROP INDEX IF EXISTS idx_food_preferences_device_id;
CREATE UNIQUE INDEX IF NOT EXISTS idx_food_preferences_user_food ON public.food_preferences (user_id, food_name);
CREATE INDEX IF NOT EXISTS idx_food_preferences_user_id ON public.food_preferences (user_id);
CREATE INDEX IF NOT EXISTS idx_food_preferences_preference ON public.food_preferences (preference);

ALTER TABLE public.food_preferences DROP COLUMN IF EXISTS device_id;

-------------------------------------------------------------------------------
-- Section 5: Clean up deprecated columns / tables / indexes
-------------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_foods_suitable_for_activities;
ALTER TABLE public.foods
  DROP COLUMN IF EXISTS suitable_for_activities,
  DROP COLUMN IF EXISTS before_run_suitable,
  DROP COLUMN IF EXISTS during_run_suitable,
  DROP COLUMN IF EXISTS after_run_suitable,
  DROP COLUMN IF EXISTS run_portable,
  DROP COLUMN IF EXISTS requires_preparation,
  DROP COLUMN IF EXISTS aid_station_available,
  DROP COLUMN IF EXISTS cycling_suitable,
  DROP COLUMN IF EXISTS swimming_suitable;

ALTER TABLE public.user_foods
  DROP COLUMN IF EXISTS suitable_for_activities;

DROP TABLE IF EXISTS public.food_categories;
DROP TABLE IF EXISTS public.user_food_categories;
DROP TABLE IF EXISTS public.carb_loading_food_meal_types;
DROP TABLE IF EXISTS public.carb_loading_user_food_meal_types;
DROP TABLE IF EXISTS public.categories;
DROP TABLE IF EXISTS public.meal_types;
DROP TABLE IF EXISTS public.edge_functions;

-------------------------------------------------------------------------------
-- Section 6: Rebuild essential indexes that were dropped earlier
-------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_events_activity ON public.events (activity_id) WHERE activity_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_activity_id ON public.nutrition_plans (activity_id) WHERE activity_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_carb_plans_event ON public.carb_loading_plans (event_id) WHERE event_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_carb_days_plan ON public.carb_loading_days (carb_loading_plan_id);
CREATE INDEX IF NOT EXISTS idx_carb_day_meals_day ON public.carb_loading_day_meals (carb_loading_day_id);
CREATE INDEX IF NOT EXISTS idx_foods_categories_gin ON public.foods USING gin (categories);
CREATE INDEX IF NOT EXISTS idx_foods_activity_types_gin ON public.foods USING gin (activity_types);
CREATE INDEX IF NOT EXISTS idx_user_foods_categories_gin ON public.user_foods USING gin (categories);
CREATE INDEX IF NOT EXISTS idx_user_foods_activity_types_gin ON public.user_foods USING gin (activity_types);

-- Drop any leftover RLS policies now that we rely on dev-only grants
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
-- Section 7: Dev-only security posture (RLS off, wide-open grants)
-------------------------------------------------------------------------------
ALTER TABLE public.users                      DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_content                DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.foods                      DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_foods                 DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_preferences           DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities                 DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.events                     DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_plans            DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_plans         DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_days          DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_day_meals     DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_notes              DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_foods         DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.carb_loading_user_foods    DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_survey_responses   DISABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO service_role;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO service_role;

COMMIT;
