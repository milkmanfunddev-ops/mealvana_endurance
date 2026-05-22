-- Migration: Fix activities and events schema
-- Date: 2025-10-10
-- Purpose:
--   1. Change activities.activity_type to support 'running', 'cycling', 'swimming' (not 'event')
--   2. Make events.activity_id nullable and remove unique constraint (events may exist without activities)

-- Step 1: Drop the existing check constraint on activities.activity_type
ALTER TABLE activities
DROP CONSTRAINT IF EXISTS activities_activity_type_check;

-- Step 2: Add new check constraint with correct activity types
ALTER TABLE activities
ADD CONSTRAINT activities_activity_type_check
CHECK (activity_type IN ('running', 'cycling', 'swimming'));

-- Step 3: Drop the unique constraint on events.activity_id (if it exists)
-- This allows multiple events to reference the same activity, or no activity at all
ALTER TABLE events
DROP CONSTRAINT IF EXISTS events_activity_id_key;

-- Step 4: Make events.activity_id nullable (it may already be nullable, but ensure it)
ALTER TABLE events
ALTER COLUMN activity_id DROP NOT NULL;

-- Note: Any existing data with activity_type='event' will need to be manually updated
-- to one of the valid types ('running', 'cycling', 'swimming')
