-- raw-retention sweep: post to the raw-retention-alert edge function on EVERY
-- run, not only when an alert fires (Sentry ticket 12, cron monitor
-- `raw-retention-sweep`).
--
-- Why: the edge function now sends the Sentry cron check-in (in_progress →
-- ok/error). A check-in that only happens on alert nights is indistinguishable
-- from a dead scheduler on quiet nights, which is exactly the case the monitor
-- exists for. The audit row stays the record; the email is still sent only
-- when an alert direction fired (the function decides, from `alerted`).
--
-- Body shape posted (the function also still accepts the old bare audit row):
--   { "audit": <raw_retention_audit row>, "sweep_status": "ok"|"error",
--     "sweep_error": <text, on error>, "alerted": <bool> }
--
-- A failure inside raw_retention_sweep() is reported with sweep_status=error
-- and the function returns a NULL row with a WARNING instead of re-raising:
-- pg_net queues the POST in this transaction, so an exception here would
-- roll the report back and the only signal left would be the missed
-- check-in. The explicit `error` check-in plus the captured message are the
-- louder, faster signal.
--
-- Idempotent: CREATE OR REPLACE; the cron job keeps calling the same name.
-- Vault secrets as before (seeded per environment, never in a migration):
--   raw_retention_alert_url, raw_retention_alert_token.
-- Convention: timestamps are timestamptz (UTC), as in the sweep itself.

CREATE OR REPLACE FUNCTION public.raw_retention_sweep_and_notify(
  p_plan_bytes BIGINT DEFAULT 8589934592
) RETURNS public.raw_retention_audit
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_audit public.raw_retention_audit;
  v_url TEXT;
  v_token TEXT;
  v_alerted BOOLEAN := false;
  v_status TEXT := 'ok';
  v_error TEXT := NULL;
BEGIN
  BEGIN
    v_audit := public.raw_retention_sweep(now(), p_plan_bytes);
    v_alerted := v_audit.oversize_alert
      OR jsonb_array_length(v_audit.underarrival_alerts) > 0;
  EXCEPTION WHEN OTHERS THEN
    v_status := 'error';
    v_error := SQLSTATE || ': ' || SQLERRM;
  END;

  SELECT decrypted_secret INTO v_url
    FROM vault.decrypted_secrets WHERE name = 'raw_retention_alert_url';
  SELECT decrypted_secret INTO v_token
    FROM vault.decrypted_secrets WHERE name = 'raw_retention_alert_token';

  IF v_url IS NULL OR v_token IS NULL THEN
    RAISE NOTICE 'raw_retention sweep ran (status %, alerted %) but vault secrets are not seeded — report skipped',
      v_status, v_alerted;
  ELSE
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-alert-token', v_token
      ),
      body := jsonb_build_object(
        'audit', to_jsonb(v_audit),
        'sweep_status', v_status,
        'sweep_error', v_error,
        'alerted', v_alerted
      )
    );
  END IF;

  IF v_status = 'error' THEN
    RAISE WARNING 'raw_retention_sweep failed: %', v_error;
  END IF;

  RETURN v_audit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.raw_retention_sweep_and_notify(BIGINT)
  FROM PUBLIC, anon, authenticated;
