-- Migration: Merge activity completions into activities table
-- Date: 2025-11-10
-- Description: Adds completion metadata columns to activities, backfills from activity_completions, and drops the legacy table.

BEGIN;

-- 1. Extend activities table with completion metadata
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS completion_type TEXT DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS average_pace_minutes_per_mile DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS max_heart_rate INTEGER,
  ADD COLUMN IF NOT EXISTS average_heart_rate INTEGER,
  ADD COLUMN IF NOT EXISTS calories_burned INTEGER,
  ADD COLUMN IF NOT EXISTS effort_rating INTEGER,
  ADD COLUMN IF NOT EXISTS nutrition_rating INTEGER,
  ADD COLUMN IF NOT EXISTS overall_satisfaction INTEGER,
  ADD COLUMN IF NOT EXISTS voice_note_id TEXT,
  ADD COLUMN IF NOT EXISTS has_voice_recording BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS weather_conditions TEXT,
  ADD COLUMN IF NOT EXISTS temperature_fahrenheit INTEGER,
  ADD COLUMN IF NOT EXISTS humidity_percent INTEGER,
  ADD COLUMN IF NOT EXISTS nutrition_adherence_score DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS performance_vs_target DOUBLE PRECISION;

-- 2. Backfill data from legacy activity_completions table when present
DO $$
BEGIN
  IF to_regclass('public.activity_completions') IS NOT NULL THEN
    RAISE NOTICE 'Backfilling completion data from activity_completions into activities';
    WITH ac_trimmed AS (
      SELECT
        ac.*,
        NULLIF(BTRIM(ac.activity_id::text), '') AS activity_id_trimmed
      FROM public.activity_completions ac
    ),
    ac_filtered AS (
      SELECT
        *,
        CASE
          WHEN activity_id_trimmed IS NOT NULL
               AND activity_id_trimmed ~ '^[0-9]+$'
            THEN activity_id_trimmed::BIGINT
          ELSE NULL
        END AS activity_id_bigint
      FROM ac_trimmed
    )
    UPDATE public.activities a
       SET completed_at = COALESCE(a.completed_at, ac.completed_at),
           completion_type = COALESCE(a.completion_type, 'manual'),
           completion_notes = COALESCE(ac.completion_notes, a.completion_notes),
           completion_rating = COALESCE(ac.completion_rating, a.completion_rating),
           actual_distance_miles = COALESCE(ac.actual_distance_miles, a.actual_distance_miles),
           actual_duration_minutes = COALESCE(ac.actual_duration_minutes, a.actual_duration_minutes),
           average_pace_minutes_per_mile = COALESCE(ac.average_pace_minutes_per_mile, a.average_pace_minutes_per_mile)
      FROM ac_filtered ac
     WHERE ac.activity_id_bigint IS NOT NULL
       AND a.id = ac.activity_id_bigint;
  END IF;
END $$;

-- 3. Drop the legacy table now that data lives on activities
DROP TABLE IF EXISTS public.activity_completions CASCADE;

COMMIT;
