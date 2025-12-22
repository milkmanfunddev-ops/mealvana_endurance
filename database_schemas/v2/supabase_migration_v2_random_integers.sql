-- ============================================================
-- Supabase Migration: v2 - Random Integer IDs
-- ============================================================
-- Changes:
-- 1. Convert carb loading table IDs from TEXT to BIGINT
-- 2. Convert feature_survey_responses.id from TEXT to BIGINT
-- 3. Rename feature_survey_responses.user_id to device_id
-- 4. Add CASCADE DELETE constraints for event deletion chain
--
-- Safe to run multiple times (idempotent where possible)
-- ============================================================

BEGIN;

-- ============================================================
-- STEP 1: Drop existing foreign key constraints
-- ============================================================
-- We need to drop FK constraints before changing column types

-- Drop carb_loading_days FK to carb_loading_plans
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'carb_loading_days_plan_fk'
        AND table_name = 'carb_loading_days'
    ) THEN
        ALTER TABLE carb_loading_days
        DROP CONSTRAINT carb_loading_days_plan_fk;
    END IF;
END $$;

-- Drop carb_loading_day_meals FK to carb_loading_days
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'carb_loading_day_meals_carb_loading_day_id_fkey'
        AND table_name = 'carb_loading_day_meals'
    ) THEN
        ALTER TABLE carb_loading_day_meals
        DROP CONSTRAINT carb_loading_day_meals_carb_loading_day_id_fkey;
    END IF;
END $$;

-- Drop carb_loading_plans FK to events (if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'carb_loading_plans_event_id_fkey'
        AND table_name = 'carb_loading_plans'
    ) THEN
        ALTER TABLE carb_loading_plans
        DROP CONSTRAINT carb_loading_plans_event_id_fkey;
    END IF;
END $$;

-- Drop events.activity_id FK to activities (we'll recreate with CASCADE)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'events_activity_fkey'
        AND table_name = 'events'
    ) THEN
        ALTER TABLE events
        DROP CONSTRAINT events_activity_fkey;
    END IF;
END $$;

-- ============================================================
-- STEP 2: Change column types from TEXT to BIGINT
-- ============================================================
-- Only convert if column is currently TEXT, skip if already BIGINT

-- carb_loading_plans.id
DO $$
DECLARE
    col_type TEXT;
BEGIN
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_name = 'carb_loading_plans' AND column_name = 'id';

    IF col_type = 'text' OR col_type = 'character varying' THEN
        ALTER TABLE carb_loading_plans
            ALTER COLUMN id TYPE BIGINT USING CASE
                WHEN id ~ '^[0-9]+$' THEN id::BIGINT
                ELSE NULL
            END;
        RAISE NOTICE 'Converted carb_loading_plans.id from % to BIGINT', col_type;
    ELSE
        RAISE NOTICE 'carb_loading_plans.id already %', col_type;
    END IF;
END $$;

-- carb_loading_plans.event_id
DO $$
DECLARE
    col_type TEXT;
BEGIN
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_name = 'carb_loading_plans' AND column_name = 'event_id';

    IF col_type = 'text' OR col_type = 'character varying' THEN
        ALTER TABLE carb_loading_plans
            ALTER COLUMN event_id TYPE BIGINT USING CASE
                WHEN event_id ~ '^[0-9]+$' THEN event_id::BIGINT
                ELSE NULL
            END;
        RAISE NOTICE 'Converted carb_loading_plans.event_id from % to BIGINT', col_type;
    ELSE
        RAISE NOTICE 'carb_loading_plans.event_id already %', col_type;
    END IF;
END $$;

-- carb_loading_days.id
DO $$
DECLARE
    col_type TEXT;
BEGIN
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_name = 'carb_loading_days' AND column_name = 'id';

    IF col_type = 'text' OR col_type = 'character varying' THEN
        ALTER TABLE carb_loading_days
            ALTER COLUMN id TYPE BIGINT USING CASE
                WHEN id ~ '^[0-9]+$' THEN id::BIGINT
                ELSE NULL
            END;
        RAISE NOTICE 'Converted carb_loading_days.id from % to BIGINT', col_type;
    ELSE
        RAISE NOTICE 'carb_loading_days.id already %', col_type;
    END IF;
END $$;

-- carb_loading_days.carb_loading_plan_id
DO $$
DECLARE
    col_type TEXT;
BEGIN
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_name = 'carb_loading_days' AND column_name = 'carb_loading_plan_id';

    IF col_type = 'text' OR col_type = 'character varying' THEN
        ALTER TABLE carb_loading_days
            ALTER COLUMN carb_loading_plan_id TYPE BIGINT USING CASE
                WHEN carb_loading_plan_id ~ '^[0-9]+$' THEN carb_loading_plan_id::BIGINT
                ELSE NULL
            END;
        RAISE NOTICE 'Converted carb_loading_days.carb_loading_plan_id from % to BIGINT', col_type;
    ELSE
        RAISE NOTICE 'carb_loading_days.carb_loading_plan_id already %', col_type;
    END IF;
END $$;

-- carb_loading_day_meals.id (NOTE: This is UUID in prod schema, not TEXT)
-- Skip this one as it's already UUID in production

-- carb_loading_day_meals.carb_loading_day_id
DO $$
DECLARE
    col_type TEXT;
BEGIN
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_name = 'carb_loading_day_meals' AND column_name = 'carb_loading_day_id';

    IF col_type = 'text' OR col_type = 'character varying' THEN
        ALTER TABLE carb_loading_day_meals
            ALTER COLUMN carb_loading_day_id TYPE BIGINT USING CASE
                WHEN carb_loading_day_id ~ '^[0-9]+$' THEN carb_loading_day_id::BIGINT
                ELSE NULL
            END;
        RAISE NOTICE 'Converted carb_loading_day_meals.carb_loading_day_id from % to BIGINT', col_type;
    ELSE
        RAISE NOTICE 'carb_loading_day_meals.carb_loading_day_id already %', col_type;
    END IF;
END $$;

-- feature_survey_responses.id - SKIP (already bigserial in production)
-- The client uses random integers locally but Supabase auto-generates with bigserial
-- Client doesn't send 'id' field during sync - let Supabase handle it
DO $$
BEGIN
    RAISE NOTICE 'Skipping feature_survey_responses.id - already bigserial in production';
END $$;

-- ============================================================
-- STEP 3: Rename feature_survey_responses.user_id to device_id
-- ============================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'feature_survey_responses'
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE feature_survey_responses
        RENAME COLUMN user_id TO device_id;
        RAISE NOTICE 'Renamed feature_survey_responses.user_id to device_id';
    ELSE
        RAISE NOTICE 'feature_survey_responses.device_id already exists (or user_id does not exist)';
    END IF;
END $$;

-- ============================================================
-- STEP 4: Add CASCADE DELETE foreign key constraints
-- ============================================================

-- carb_loading_plans → events (CASCADE DELETE)
-- When an event is deleted, cascade delete all associated carb loading plans
ALTER TABLE carb_loading_plans
ADD CONSTRAINT carb_loading_plans_event_id_fkey
FOREIGN KEY (event_id)
REFERENCES events(id)
ON DELETE CASCADE;

-- carb_loading_days → carb_loading_plans (CASCADE DELETE)
-- When a plan is deleted, cascade delete all associated days
ALTER TABLE carb_loading_days
ADD CONSTRAINT carb_loading_days_plan_fk
FOREIGN KEY (carb_loading_plan_id)
REFERENCES carb_loading_plans(id)
ON DELETE CASCADE;

-- carb_loading_day_meals → carb_loading_days (CASCADE DELETE)
-- When a day is deleted, cascade delete all associated meals
ALTER TABLE carb_loading_day_meals
ADD CONSTRAINT carb_loading_day_meals_carb_loading_day_id_fkey
FOREIGN KEY (carb_loading_day_id)
REFERENCES carb_loading_days(id)
ON DELETE CASCADE;

-- events.activity_id → activities (CASCADE DELETE)
-- When an activity is deleted, cascade delete the associated event
-- CORRECTED: The FK is on events.activity_id, not activities.event_id
ALTER TABLE events
ADD CONSTRAINT events_activity_fkey
FOREIGN KEY (activity_id)
REFERENCES activities(id)
ON DELETE CASCADE;

-- ============================================================
-- STEP 5: Validation Queries
-- ============================================================

-- Verify column types
DO $$
DECLARE
    plan_id_type TEXT;
    day_id_type TEXT;
BEGIN
    SELECT data_type INTO plan_id_type
    FROM information_schema.columns
    WHERE table_name = 'carb_loading_plans' AND column_name = 'id';

    SELECT data_type INTO day_id_type
    FROM information_schema.columns
    WHERE table_name = 'carb_loading_days' AND column_name = 'id';

    RAISE NOTICE 'carb_loading_plans.id type: %', plan_id_type;
    RAISE NOTICE 'carb_loading_days.id type: %', day_id_type;

    IF plan_id_type != 'bigint' OR day_id_type != 'bigint' THEN
        RAISE EXCEPTION 'Column type conversion failed!';
    END IF;
END $$;

-- Verify CASCADE DELETE constraints exist
DO $$
DECLARE
    fk_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO fk_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.referential_constraints rc
        ON tc.constraint_name = rc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
    AND rc.delete_rule = 'CASCADE'
    AND (
        (tc.table_name = 'carb_loading_plans' AND kcu.column_name = 'event_id') OR
        (tc.table_name = 'carb_loading_days' AND kcu.column_name = 'carb_loading_plan_id') OR
        (tc.table_name = 'carb_loading_day_meals' AND kcu.column_name = 'carb_loading_day_id') OR
        (tc.table_name = 'events' AND kcu.column_name = 'activity_id')
    );

    RAISE NOTICE 'CASCADE DELETE constraints created: %', fk_count;

    IF fk_count < 4 THEN
        RAISE EXCEPTION 'Expected 4 CASCADE DELETE constraints, found %', fk_count;
    END IF;
END $$;

-- Verify device_id column exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'feature_survey_responses'
        AND column_name = 'device_id'
    ) THEN
        RAISE EXCEPTION 'feature_survey_responses.device_id column does not exist!';
    END IF;

    RAISE NOTICE 'feature_survey_responses.device_id column verified';
END $$;

COMMIT;

-- ============================================================
-- Migration Complete
-- ============================================================
-- Summary of changes:
-- ✓ Converted carb loading table IDs from TEXT to BIGINT
-- ✓ Skipped feature_survey_responses.id (already bigserial in production)
-- ✓ Renamed feature_survey_responses.user_id to device_id
-- ✓ Added CASCADE DELETE chain: events → plans → days → meals
-- ✓ Changed events.activity_id FK to CASCADE DELETE (was SET NULL)
--
-- Note: Client doesn't sync feature_survey_responses.id to Supabase
--       Supabase auto-generates IDs using bigserial sequence
-- ============================================================
