-- Migration: Add Missing Events Table Columns
-- Date: 2025-10-30
-- Description: Adds all missing columns to events table to match Drift schema

-- Add event classification columns
ALTER TABLE "public"."events"
ADD COLUMN IF NOT EXISTS "event_type" TEXT,
ADD COLUMN IF NOT EXISTS "event_subtype" TEXT;

-- Add event details columns
ALTER TABLE "public"."events"
ADD COLUMN IF NOT EXISTS "location" TEXT,
ADD COLUMN IF NOT EXISTS "registration_url" TEXT,
ADD COLUMN IF NOT EXISTS "start_time" TEXT;

-- Add goals and targets columns
ALTER TABLE "public"."events"
ADD COLUMN IF NOT EXISTS "goal_time_minutes" INTEGER,
ADD COLUMN IF NOT EXISTS "goal_pace_minutes_per_mile" REAL,
ADD COLUMN IF NOT EXISTS "predicted_finish_time_minutes" INTEGER;

-- Add carb loading configuration columns
ALTER TABLE "public"."events"
ADD COLUMN IF NOT EXISTS "carb_loading_days" INTEGER,
ADD COLUMN IF NOT EXISTS "carb_loading_start_date" TIMESTAMPTZ;

-- Add registration and logistics columns
ALTER TABLE "public"."events"
ADD COLUMN IF NOT EXISTS "bib_number" TEXT,
ADD COLUMN IF NOT EXISTS "wave_start_time" TEXT,
ADD COLUMN IF NOT EXISTS "packet_pickup_info" TEXT;

-- Add results (post-event) columns
ALTER TABLE "public"."events"
ADD COLUMN IF NOT EXISTS "actual_finish_time_minutes" INTEGER,
ADD COLUMN IF NOT EXISTS "final_placement" INTEGER,
ADD COLUMN IF NOT EXISTS "age_group_placement" INTEGER;

-- Add constraints
ALTER TABLE "public"."events"
DROP CONSTRAINT IF EXISTS "events_event_type_check";

ALTER TABLE "public"."events"
ADD CONSTRAINT "events_event_type_check"
CHECK (event_type IS NULL OR event_type IN ('marathon', 'half_marathon', '10k', '5k', 'ultra_50k', 'ultra_50m', 'ultra_100k', 'ultra_100m', 'custom'));

ALTER TABLE "public"."events"
DROP CONSTRAINT IF EXISTS "events_carb_loading_days_check";

ALTER TABLE "public"."events"
ADD CONSTRAINT "events_carb_loading_days_check"
CHECK (carb_loading_days IS NULL OR carb_loading_days IN (1, 2, 3, 7));

-- Update comment on table
COMMENT ON TABLE "public"."events" IS 'Specialized event data linked to activities - includes race details, goals, and results';
