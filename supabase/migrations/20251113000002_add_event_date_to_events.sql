-- Migration: Add event_date column to events table
-- Purpose: Add dedicated DATE column for event dates (separate from start_time which is for precise timestamps)
-- Date: 2025-11-13

-- Add event_date column as DATE type
ALTER TABLE events
ADD COLUMN event_date DATE;

-- Migrate existing start_time values to event_date if they exist
-- This extracts the date portion from the ISO 8601 timestamp strings
UPDATE events
SET event_date = (start_time::timestamp)::date
WHERE start_time IS NOT NULL
  AND start_time != ''
  AND start_time ~ '^\d{4}-\d{2}-\d{2}';

-- Add comment to clarify purpose
COMMENT ON COLUMN events.event_date IS 'Date of the event (DATE type). Use this for calendar displays and date-based queries. start_time remains for precise race start timestamps.';

-- Create index for efficient date-based queries (important for calendar view)
CREATE INDEX idx_events_event_date ON events(event_date);

-- Note: We're keeping start_time for backward compatibility and for storing precise race start times with timezone
-- event_date is the primary field for calendar operations
