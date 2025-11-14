-- Replace event_type_enum with shared activity_type enum
-- This unifies sport type representation across activities and events
-- Migration created: 2025-11-14
-- IDEMPOTENT: Safe to run multiple times

-- Step 1: Create the shared activity_type enum that includes multi-sport types (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'activity_type_enum') THEN
    CREATE TYPE public.activity_type_enum AS ENUM (
      'running',
      'cycling',
      'swimming',
      'triathlon',
      'duathlon',
      'multisport'
    );
  END IF;
END $$;

-- Step 2: Migrate events table to use activity_type_enum (idempotent)
DO $$
BEGIN
  -- Check if events.event_type is already using activity_type_enum
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_attribute a ON a.atttypid = t.oid
    JOIN pg_class c ON c.oid = a.attrelid
    WHERE c.relname = 'events'
    AND a.attname = 'event_type'
    AND t.typname = 'activity_type_enum'
  ) THEN
    -- Migration needed: events.event_type is still using event_type_enum

    -- Add temporary column
    ALTER TABLE public.events ADD COLUMN temp_activity_type activity_type_enum;

    -- Migrate existing values (cast via text to avoid enum-to-enum issues)
    UPDATE public.events
    SET temp_activity_type = event_type::text::activity_type_enum
    WHERE event_type IS NOT NULL;

    -- Drop old column
    ALTER TABLE public.events DROP COLUMN event_type;

    -- Rename temp column
    ALTER TABLE public.events RENAME COLUMN temp_activity_type TO event_type;

    -- Make NOT NULL
    ALTER TABLE public.events ALTER COLUMN event_type SET NOT NULL;

    -- Update comment
    COMMENT ON COLUMN public.events.event_type IS 'Sport category using shared activity_type enum: running, cycling, swimming, triathlon, duathlon, multisport';
  END IF;
END $$;

-- Step 3: Drop the old event_type_enum (no longer needed)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_type_enum') THEN
    DROP TYPE public.event_type_enum;
  END IF;
END $$;

-- Step 4: Migrate activities table from sport_enum to activity_type_enum (idempotent)
-- This ensures both activities and events use the same sport type enum
DO $$
BEGIN
  -- Check if activities.activity_type is already using activity_type_enum
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_attribute a ON a.atttypid = t.oid
    JOIN pg_class c ON c.oid = a.attrelid
    WHERE c.relname = 'activities'
    AND a.attname = 'activity_type'
    AND t.typname = 'activity_type_enum'
  ) THEN
    -- Migration needed: activities.activity_type is still using sport_enum

    -- Add temporary column
    ALTER TABLE public.activities ADD COLUMN temp_activity_type activity_type_enum;

    -- Cast via text to avoid enum-to-enum casting issues
    UPDATE public.activities
    SET temp_activity_type = activity_type::text::activity_type_enum
    WHERE activity_type IS NOT NULL;

    -- Drop old column
    ALTER TABLE public.activities DROP COLUMN activity_type;

    -- Rename temp column
    ALTER TABLE public.activities RENAME COLUMN temp_activity_type TO activity_type;

    -- Make NOT NULL
    ALTER TABLE public.activities ALTER COLUMN activity_type SET NOT NULL;

    -- Update comment
    COMMENT ON COLUMN public.activities.activity_type IS 'Sport category using shared activity_type enum: running, cycling, swimming, triathlon, duathlon, multisport';
  END IF;

  -- Also drop sport_type column if it exists (legacy column)
  IF EXISTS (
    SELECT 1 FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    WHERE c.relname = 'activities'
    AND a.attname = 'sport_type'
  ) THEN
    ALTER TABLE public.activities DROP COLUMN sport_type;
  END IF;
END $$;

-- Step 5: Migrate foods.activity_types array from sport_enum[] to activity_type_enum[] (idempotent)
DO $$
BEGIN
  -- Check if foods.activity_types exists and uses sport_enum[]
  IF EXISTS (
    SELECT 1 FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_type t ON t.oid = a.atttypid
    WHERE c.relname = 'foods'
    AND a.attname = 'activity_types'
    AND t.typname = '_sport_enum'  -- Array types are prefixed with underscore
  ) THEN
    -- Migrate to activity_type_enum[]
    ALTER TABLE public.foods ADD COLUMN temp_activity_types activity_type_enum[];

    -- Cast existing values via text (unnest, cast each element, re-aggregate)
    UPDATE public.foods
    SET temp_activity_types = ARRAY(
      SELECT unnest(activity_types)::text::activity_type_enum
    )
    WHERE activity_types IS NOT NULL;

    -- Drop old column
    ALTER TABLE public.foods DROP COLUMN activity_types;

    -- Rename temp column
    ALTER TABLE public.foods RENAME COLUMN temp_activity_types TO activity_types;
  END IF;
END $$;

-- Step 6: Migrate user_foods.activity_types array from sport_enum[] to activity_type_enum[] (idempotent)
DO $$
BEGIN
  -- Check if user_foods.activity_types exists and uses sport_enum[]
  IF EXISTS (
    SELECT 1 FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_type t ON t.oid = a.atttypid
    WHERE c.relname = 'user_foods'
    AND a.attname = 'activity_types'
    AND t.typname = '_sport_enum'  -- Array types are prefixed with underscore
  ) THEN
    -- Migrate to activity_type_enum[]
    ALTER TABLE public.user_foods ADD COLUMN temp_activity_types activity_type_enum[];

    -- Cast existing values via text (unnest, cast each element, re-aggregate)
    UPDATE public.user_foods
    SET temp_activity_types = ARRAY(
      SELECT unnest(activity_types)::text::activity_type_enum
    )
    WHERE activity_types IS NOT NULL;

    -- Drop old column
    ALTER TABLE public.user_foods DROP COLUMN activity_types;

    -- Rename temp column
    ALTER TABLE public.user_foods RENAME COLUMN temp_activity_types TO activity_types;
  END IF;
END $$;

-- Step 7: Drop the old sport_enum if it exists (only after all dependencies are removed)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sport_enum') THEN
    DROP TYPE public.sport_enum;
  END IF;
END $$;
