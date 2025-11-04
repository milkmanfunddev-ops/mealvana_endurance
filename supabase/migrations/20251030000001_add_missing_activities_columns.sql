-- Migration: Add Missing Activities Table Columns
-- Date: 2025-10-30
-- Description: Adds all missing columns to activities table to match Drift schema

-- Add missing core columns
ALTER TABLE "public"."activities"
ADD COLUMN IF NOT EXISTS "title" TEXT,
ADD COLUMN IF NOT EXISTS "scheduled_date_time" TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS "pace_target_minutes_per_mile" REAL,
ADD COLUMN IF NOT EXISTS "intensity_level" TEXT;

-- Add completion tracking columns
ALTER TABLE "public"."activities"
ADD COLUMN IF NOT EXISTS "completed_at" TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS "completion_rating" INTEGER,
ADD COLUMN IF NOT EXISTS "completion_notes" TEXT,
ADD COLUMN IF NOT EXISTS "actual_distance_miles" NUMERIC(5,2),
ADD COLUMN IF NOT EXISTS "actual_duration_minutes" INTEGER;

-- Add reminder settings columns
ALTER TABLE "public"."activities"
ADD COLUMN IF NOT EXISTS "reminder_enabled" BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS "reminder_days_before" INTEGER,
ADD COLUMN IF NOT EXISTS "reminder_time_of_day" TEXT,
ADD COLUMN IF NOT EXISTS "reminder_recurring" BOOLEAN DEFAULT false;

-- Add soft delete column
ALTER TABLE "public"."activities"
ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS "notes" TEXT;

-- Add constraints
ALTER TABLE "public"."activities"
DROP CONSTRAINT IF EXISTS "activities_intensity_level_check";

ALTER TABLE "public"."activities"
ADD CONSTRAINT "activities_intensity_level_check"
CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race'));

ALTER TABLE "public"."activities"
DROP CONSTRAINT IF EXISTS "activities_completion_rating_check";

ALTER TABLE "public"."activities"
ADD CONSTRAINT "activities_completion_rating_check"
CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5));

-- Update comment on table
COMMENT ON TABLE "public"."activities" IS 'Calendar entries for workouts and training activities across running, cycling, and swimming';
