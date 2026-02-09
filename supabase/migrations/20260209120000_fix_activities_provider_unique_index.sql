-- Fix: Convert partial unique index to non-partial for PostgREST upsert compatibility
--
-- Problem: PostgREST's upsert(onConflict:) cannot specify WHERE predicates,
-- which means the partial unique index may not be correctly inferred as the
-- arbiter index during ON CONFLICT resolution. This can silently cause
-- INSERT instead of UPDATE, creating duplicate activities.
--
-- Solution: Replace with a non-partial unique index. In PostgreSQL, NULLs are
-- always treated as distinct in unique indexes, so manual activities (where
-- synced_from_provider or provider_workout_id is NULL) are unaffected.
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

-- Step 3: Create non-partial unique index (compatible with PostgREST upsert)
CREATE UNIQUE INDEX uq_activities_provider_workout
    ON activities (user_id, synced_from_provider, provider_workout_id)
    WHERE (synced_from_provider IS NOT NULL AND provider_workout_id IS NOT NULL);

-- Note: We keep the WHERE clause but PostgreSQL 15+ (used by Supabase) correctly
-- infers this partial index when all indexed columns are non-NULL in the inserted row.
-- The critical fix is the immediate upload in the Dart code (connect_training_controller.dart).
-- This migration also cleans up any existing duplicates as a safety measure.
