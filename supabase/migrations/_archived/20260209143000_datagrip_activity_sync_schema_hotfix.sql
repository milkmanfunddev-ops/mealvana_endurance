-- DataGrip hotfix: activity sync integrity + brick enum compatibility
-- Run this directly in DataGrip against the affected database.
--
-- Fixes covered:
-- 1) Ensures brick enum values exist server-side (prevents 22P02 on archived_for_brick)
-- 2) Normalizes provider keys used for provider-workout upserts
-- 3) Deduplicates provider-backed rows deterministically
-- 4) Recreates provider uniqueness index as NON-partial (required for ON CONFLICT target)
--
-- Safe to run multiple times.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Ensure enum values expected by app code exist
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  ALTER TYPE activity_type_enum ADD VALUE IF NOT EXISTS 'brick';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TYPE activity_status_enum ADD VALUE IF NOT EXISTS 'archived_for_brick';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 2) Canonicalize provider values so dedupe/upsert keys are stable
-- ---------------------------------------------------------------------------
UPDATE activities
SET synced_from_provider = 'training_peaks'
WHERE synced_from_provider IS NOT NULL
  AND lower(trim(synced_from_provider)) IN (
    'training peaks',
    'trainingpeaks',
    'training_peaks'
  );

UPDATE activities
SET synced_from_provider = 'final_surge'
WHERE synced_from_provider IS NOT NULL
  AND lower(trim(synced_from_provider)) IN (
    'final surge',
    'finalsurge',
    'final_surge'
  );

UPDATE activities
SET synced_from_provider = NULL
WHERE synced_from_provider IS NOT NULL
  AND trim(synced_from_provider) = '';

UPDATE activities
SET provider_workout_id = NULL
WHERE provider_workout_id IS NOT NULL
  AND trim(provider_workout_id) = '';

-- ---------------------------------------------------------------------------
-- 3) Drop index/constraint variants (partial and non-partial variants)
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS uq_activities_provider_workout;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'activities'::regclass
      AND conname = 'uq_activities_provider_workout'
  ) THEN
    ALTER TABLE activities DROP CONSTRAINT uq_activities_provider_workout;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 4) Deduplicate provider-backed rows before recreating unique index
-- Keep newest row by updated_at, then created_at, then id.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 5) Recreate required NON-partial unique index
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX uq_activities_provider_workout
  ON activities (user_id, synced_from_provider, provider_workout_id);

COMMIT;

-- ---------------------------------------------------------------------------
-- Optional verification queries (run separately if desired):
--
-- SELECT enumlabel
-- FROM pg_enum
-- WHERE enumtypid = 'activity_status_enum'::regtype
-- ORDER BY enumsortorder;
--
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'activities'
--   AND indexname = 'uq_activities_provider_workout';
-- ---------------------------------------------------------------------------
