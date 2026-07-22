-- Allow 'runna' as an integrations provider.
-- The Runna integration stores its iCal feed URL as the row's access_token;
-- without this, the client's uploadDirtyRecords silently queues the row
-- forever (23514 swallowed into UploadResult.failed()).
-- Idempotent: drop + recreate the CHECK with the full provider list.

ALTER TABLE integrations
  DROP CONSTRAINT IF EXISTS integrations_provider_check;

ALTER TABLE integrations
  ADD CONSTRAINT integrations_provider_check
  CHECK (provider = ANY (ARRAY[
    'final_surge'::text,
    'training_peaks'::text,
    'strava'::text,
    'garmin'::text,
    'vdot'::text,
    'runna'::text
  ]));
