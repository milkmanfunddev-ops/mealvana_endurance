-- Q-INT8 token custody (data-integrations@v1 Stage D, RULED Xuan 2026-09-10):
-- `integrations` is the SOLE token custodian.
--
-- This strips the token copies from garmin_user_mappings (the mapping keeps
-- only the identity link garmin_user_id <-> user_id). The columns stay (a
-- drop is hygiene-batch work, Q-INT25) but are nulled and never written
-- again — garmin-user-mapping stops persisting them and garmin-backfill
-- reads/refreshes tokens on the integrations row.
--
-- DEPLOY ORDERING (runbook standing order): apply AFTER the garmin-backfill
-- and garmin-user-mapping function deploys — the pre-refactor functions
-- still read these copies, so stripping first would break backfill until
-- the deploy lands. The statement is idempotent.

UPDATE public.garmin_user_mappings
SET access_token = NULL,
    refresh_token = NULL,
    token_expires_at = NULL,
    updated_at = now()
WHERE access_token IS NOT NULL
   OR refresh_token IS NOT NULL
   OR token_expires_at IS NOT NULL;

COMMENT ON COLUMN public.garmin_user_mappings.access_token IS
  'DEAD (Q-INT8, 2026-09-11): tokens live on integrations only; column drops with the Q-INT25 hygiene batch';
COMMENT ON COLUMN public.garmin_user_mappings.refresh_token IS
  'DEAD (Q-INT8, 2026-09-11): tokens live on integrations only; column drops with the Q-INT25 hygiene batch';
