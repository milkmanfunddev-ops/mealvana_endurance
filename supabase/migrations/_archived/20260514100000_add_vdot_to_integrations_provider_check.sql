-- =============================================================================
-- Allow 'vdot' as a provider in the integrations table.
--
-- The original integrations table CHECK constraint hardcoded the supported
-- providers. Adding the V.O2 (VDOT) integration requires extending that list.
-- =============================================================================

ALTER TABLE integrations
  DROP CONSTRAINT IF EXISTS integrations_provider_check;

ALTER TABLE integrations
  ADD CONSTRAINT integrations_provider_check
  CHECK (provider IN ('final_surge', 'training_peaks', 'strava', 'garmin', 'vdot'));
