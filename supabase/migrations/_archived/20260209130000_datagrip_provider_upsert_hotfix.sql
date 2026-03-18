-- DataGrip hotfix: provider upsert + duplicate cleanup for activities
-- Run this directly against your target DB.
--
-- What this does:
-- 1) Ensures brick enum values exist (prevents 22P02 on archived_for_brick)
-- 2) Normalizes provider key values used by sync
-- 3) Converts blank provider fields to NULL
-- 4) Removes duplicate provider workouts deterministically
-- 5) Recreates provider uniqueness index as NON-partial
--
-- Safe to run multiple times.

BEGIN;

-- Ensure app enum values exist on this DB.
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

-- Canonicalize known provider names so uniqueness is consistent.
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

-- Treat blank values as NULL so they do not participate in provider uniqueness.
UPDATE activities
SET synced_from_provider = NULL
WHERE synced_from_provider IS NOT NULL
  AND trim(synced_from_provider) = '';

UPDATE activities
SET provider_workout_id = NULL
WHERE provider_workout_id IS NOT NULL
  AND trim(provider_workout_id) = '';

-- Drop index/constraint variants if present.
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

-- Deduplicate provider-backed rows (keep newest deterministically).
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

-- Recreate NON-partial unique index.
-- NULLs remain unrestricted (manual/brick activities are unaffected).
CREATE UNIQUE INDEX uq_activities_provider_workout
  ON activities (user_id, synced_from_provider, provider_workout_id);

COMMIT;
