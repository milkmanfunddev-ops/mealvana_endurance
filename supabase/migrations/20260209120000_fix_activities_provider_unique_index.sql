-- Fix: Convert partial unique index to non-partial for data integrity
--
-- Problem: The original partial unique index with WHERE clause was not
-- compatible with PostgREST's upsert(onConflict:) which caused error 42P10:
-- "there is no unique or exclusion constraint matching the ON CONFLICT specification"
-- This prevented activities from being uploaded to Supabase, causing duplicates
-- on logout→login→re-sync cycles.
--
-- Solution: Two-pronged fix:
-- 1. Dart code now uses onConflict: 'id' (primary key) for all upserts
-- 2. This migration replaces the partial index with a non-partial one as
--    a safety net for data integrity
--
-- In PostgreSQL, NULLs are always treated as distinct in unique indexes,
-- so manual activities (where synced_from_provider or provider_workout_id
-- is NULL) are unaffected by the non-partial index.
--
-- Before applying: Verify no duplicate (user_id, synced_from_provider, provider_workout_id)
-- rows exist, or remove them first:
--
--   SELECT user_id, synced_from_provider, provider_workout_id, COUNT(*)
--   FROM activities
--   WHERE synced_from_provider IS NOT NULL AND provider_workout_id IS NOT NULL
--   GROUP BY user_id, synced_from_provider, provider_workout_id
--   HAVING COUNT(*) > 1;

-- Step 1: Drop the partial unique index
DROP INDEX IF EXISTS uq_activities_provider_workout;

-- Step 2: Clean up any existing duplicates (keep the most recently updated row)
DELETE FROM activities a
USING activities b
WHERE a.user_id = b.user_id
  AND a.synced_from_provider = b.synced_from_provider
  AND a.provider_workout_id = b.provider_workout_id
  AND a.synced_from_provider IS NOT NULL
  AND a.provider_workout_id IS NOT NULL
  AND a.updated_at < b.updated_at;

-- Step 3: Create NON-partial unique index (no WHERE clause)
-- NULLs are always distinct in PostgreSQL unique indexes, so rows with
-- NULL synced_from_provider or provider_workout_id (manual activities)
-- will never conflict with each other.
CREATE UNIQUE INDEX uq_activities_provider_workout
    ON activities (user_id, synced_from_provider, provider_workout_id);
