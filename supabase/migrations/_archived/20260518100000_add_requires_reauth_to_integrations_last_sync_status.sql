-- =============================================================================
-- Allow 'requires_reauth' as an integrations.last_sync_status value.
--
-- The original integrations table CHECK constraint hardcoded the allowed
-- status values to ('success', 'error', 'pending'), but all three sync
-- services (Final Surge, TrainingPeaks, V.O2) write 'requires_reauth' when
-- the refresh-token grant fails and the user must reconnect.
--
-- This was a latent bug — no one had hit refresh-token expiry until V.O2
-- exercised the path on 2026-05-18.
-- =============================================================================

ALTER TABLE integrations
  DROP CONSTRAINT IF EXISTS integrations_last_sync_status_check;

ALTER TABLE integrations
  ADD CONSTRAINT integrations_last_sync_status_check
  CHECK (
    last_sync_status IS NULL
    OR last_sync_status IN ('success', 'error', 'pending', 'requires_reauth')
  );
