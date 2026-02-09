-- Fix provider upsert conflict resolution for activities.
--
-- Why:
-- PostgREST upsert(onConflict:) can only target plain unique indexes/constraints.
-- The previous partial unique index on (user_id, synced_from_provider, provider_workout_id)
-- is not reliably inferred by ON CONFLICT, which caused 42P10 errors and dirty uploads.
--
-- Outcome:
-- 1) Remove duplicate provider rows (keep newest)
-- 2) Recreate uq_activities_provider_workout as a NON-partial unique index
--    so provider-based upserts can resolve conflicts correctly.

-- Drop prior index form (partial) if present.
DROP INDEX IF EXISTS uq_activities_provider_workout;

-- Remove existing duplicates for provider-backed rows.
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, synced_from_provider, provider_workout_id
      ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
    ) AS rn
  FROM activities
  WHERE synced_from_provider IS NOT NULL
    AND provider_workout_id IS NOT NULL
)
DELETE FROM activities a
USING ranked r
WHERE a.id = r.id
  AND r.rn > 1;

-- Create non-partial unique index.
-- NULL provider fields remain unrestricted (manual + brick rows unaffected).
CREATE UNIQUE INDEX uq_activities_provider_workout
  ON activities (user_id, synced_from_provider, provider_workout_id);
