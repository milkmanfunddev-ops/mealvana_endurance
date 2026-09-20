-- Alert email wiring for the raw-retention sweep (real-payload-corpus@v1).
--
-- Re-enables pg_net DELIBERATELY and BY MIGRATION. History note: the extension
-- was never dropped on purpose — the 2025-12 remote_schema auto-diff mowed an
-- undeclared default extension (drop at _archived/20251216203710:2479).
-- Declaring it here is what stops the next diff doing the same.
--
-- Posture: outbound HTTP from SQL is a real capability change, so it is
-- LOCKED DOWN — EXECUTE on the net schema is revoked from anon/authenticated/
-- PUBLIC; only the service side (the cron-run wrapper below) can call it.
--
-- The wrapper posts the audit row to the raw-retention-alert edge function
-- ONLY when an alert direction fired. Its URL and shared token live in
-- Vault (secrets named below), seeded PER ENVIRONMENT outside migrations —
-- with them absent the wrapper still sweeps and records, and logs one
-- NOTICE instead of emailing. Delivery is pg_net fire-and-forget: the email
-- is a convenience channel; the audit row stays the record and the dead-man
-- Sentry check covers scheduler death.
--
-- Vault secrets (seed per env, never in a migration):
--   raw_retention_alert_url    https://<ref>.supabase.co/functions/v1/raw-retention-alert
--   raw_retention_alert_token  shared secret; must equal the function's
--                              RAW_RETENTION_ALERT_TOKEN secret

CREATE EXTENSION IF NOT EXISTS pg_net;

-- Outbound HTTP is service-side only.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA net FROM PUBLIC, anon, authenticated;

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
BEGIN
  v_audit := public.raw_retention_sweep(now(), p_plan_bytes);

  IF v_audit.oversize_alert
     OR jsonb_array_length(v_audit.underarrival_alerts) > 0 THEN
    SELECT decrypted_secret INTO v_url
      FROM vault.decrypted_secrets WHERE name = 'raw_retention_alert_url';
    SELECT decrypted_secret INTO v_token
      FROM vault.decrypted_secrets WHERE name = 'raw_retention_alert_token';

    IF v_url IS NULL OR v_token IS NULL THEN
      RAISE NOTICE 'raw_retention alert fired but vault secrets are not seeded — email skipped (audit id %)',
        v_audit.id;
    ELSE
      PERFORM net.http_post(
        url := v_url,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-alert-token', v_token
        ),
        body := to_jsonb(v_audit)
      );
    END IF;
  END IF;

  RETURN v_audit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.raw_retention_sweep_and_notify(BIGINT)
  FROM PUBLIC, anon, authenticated;

-- Re-point the daily job at the notify wrapper.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'raw-retention-sweep') THEN
    PERFORM cron.unschedule('raw-retention-sweep');
  END IF;
  PERFORM cron.schedule(
    'raw-retention-sweep',
    '17 3 * * *',
    $job$ SELECT public.raw_retention_sweep_and_notify(); $job$
  );
END;
$$;
