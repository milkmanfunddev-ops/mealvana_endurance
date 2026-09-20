-- Raw-retention TTL sweep + two-sided meter (real-payload-corpus@v1)
--
-- Contract: qa lifecycle.md L-7 items 1+4 (RULED Xuan 2026-09-20) +
-- vectors/integrations/raw-retention.json. The codebase's FIRST pg_cron job
-- (recon W1): the sweep body is a CALLABLE FUNCTION with `now` INJECTED so the
-- conformance vectors can run it against a local DB at any synthetic clock —
-- the cron entry only wraps it with the wall clock.
--
-- TTL semantics (vector-pinned): purge rows STRICTLY older than 90 days, per
-- row, by the row's own capture clock (provider_raw_payloads.fetched_at;
-- garmin_health_data.created_at). A row EXACTLY 90.0 days old is RETAINED
-- (ratified boundary convention, vector ttl-boundary-exactly-90-retained).
--
-- Two-sided meter (L-7 item 4): every sweep writes one raw_retention_audit row
-- (sizes + counts + purge tallies) and evaluates BOTH alert directions:
--   over-size   — raw tables collectively > 2 GB, or DB > 60% of plan disk;
--   under-arrival — declarative expected_flows: a flow that yielded zero/few
--   rows in its window while its precondition held. Flows are SELF-ARMING
--   (recon W6): a flow arms on its FIRST-EVER row — proof a capable client
--   exists — and never keys on last_sync_status (proven liar).
-- Corpus-exemplar novelty is deliberately NOT a flow: novelty decaying to
-- zero is the design working (L-7 item 4, deliberate exclusion).
--
-- Alert DELIVERY (email via the send-nutrition-plan-email pattern) is a
-- follow-up piece: pg_net is not enabled in this database (dropped in the
-- 2025-12 remote_schema cleanup), so the sweep records alerts on the audit
-- row and the email leg lands with the raw-retention-alert edge function +
-- pg_net wiring. The dead-man clause (client-side Sentry check on audit-row
-- freshness) covers the scheduler-death case regardless.
--
-- Deploy order (recon W8): this migration AFTER the provider_raw_payloads
-- table; expected_flows SEEDING happens LAST, after capable clients exist —
-- this migration deliberately seeds NOTHING.

-- ---------------------------------------------------------------------------
-- Audit table: one row per sweep. Service-side only.
CREATE TABLE IF NOT EXISTS public.raw_retention_audit (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  swept_at TIMESTAMPTZ NOT NULL,          -- the sweep's injected now
  purged JSONB NOT NULL,                  -- {table_or_type: rows_purged}
  row_counts JSONB NOT NULL,              -- {table_or_type: surviving_rows}
  raw_total_bytes BIGINT NOT NULL,
  db_total_bytes BIGINT NOT NULL,
  oversize_alert BOOLEAN NOT NULL,
  underarrival_alerts JSONB NOT NULL,     -- [flow, ...] that fired
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Dead-man clause reads "newest audit row age" from the client during sync;
-- the index keeps that probe and ledger reads cheap.
CREATE INDEX IF NOT EXISTS idx_raw_retention_audit_swept_at
  ON public.raw_retention_audit (swept_at DESC);

ALTER TABLE public.raw_retention_audit ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated can read retention audit" ON public.raw_retention_audit;
-- The dead-man check runs on athletes' devices: any signed-in client may read
-- sweep freshness (rows carry aggregate sizes only, no athlete data).
CREATE POLICY "Authenticated can read retention audit"
  ON public.raw_retention_audit FOR SELECT
  USING ((SELECT auth.role()) IN ('authenticated', 'service_role'));
DROP POLICY IF EXISTS "Service role full access on raw_retention_audit" ON public.raw_retention_audit;
CREATE POLICY "Service role full access on raw_retention_audit"
  ON public.raw_retention_audit FOR ALL
  USING ((SELECT auth.role()) = 'service_role');

-- ---------------------------------------------------------------------------
-- Declarative under-arrival flows. Seeded LAST (W8), never here.
CREATE TABLE IF NOT EXISTS public.expected_flows (
  flow TEXT PRIMARY KEY,
  -- What to count: 'provider_raw_payloads' rows for a provider, or
  -- 'garmin_health_data' rows for a data_type.
  source_table TEXT NOT NULL CHECK
    (source_table IN ('provider_raw_payloads', 'garmin_health_data')),
  source_filter TEXT NOT NULL,            -- provider value / data_type value
  -- Precondition kind the sweep knows how to evaluate:
  --   'active_integration:<provider>' — ≥1 active integrations row
  --   'active_garmin'                 — ≥1 garmin_user_mappings row
  precondition TEXT NOT NULL,
  min_rows INT NOT NULL DEFAULT 1,
  window_interval INTERVAL NOT NULL,
  -- Self-arming (W6): set by the sweep when the flow has its first-ever row;
  -- an unarmed flow never alerts (a mixed fleet of old clients must not
  -- false-alarm a capture no client can produce yet).
  armed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.expected_flows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Service role full access on expected_flows" ON public.expected_flows;
CREATE POLICY "Service role full access on expected_flows"
  ON public.expected_flows FOR ALL
  USING ((SELECT auth.role()) = 'service_role');

-- ---------------------------------------------------------------------------
-- The callable sweep. p_now is INJECTED (W1): cron passes the wall clock, the
-- conformance harness passes synthetic days. p_plan_bytes is the database
-- plan's disk size for the 60% threshold.
CREATE OR REPLACE FUNCTION public.raw_retention_sweep(
  p_now TIMESTAMPTZ,
  p_plan_bytes BIGINT DEFAULT 8589934592  -- 8 GiB plan disk
) RETURNS public.raw_retention_audit
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  -- Garmin raw data_types under the 90-day TTL (L-7 item 1): the two types
  -- garmin-push writes today + the ruled future sample-level capture type.
  v_garmin_raw_types CONSTANT TEXT[] :=
    ARRAY['activity_raw', 'activity_detail_raw', 'activity_detail_full'];
  v_cutoff TIMESTAMPTZ := p_now - INTERVAL '90 days';
  v_purged_prp BIGINT;
  v_purged_ghd BIGINT;
  v_count_prp BIGINT;
  v_count_ghd BIGINT;
  v_raw_bytes BIGINT;
  v_db_bytes BIGINT;
  v_flow RECORD;
  v_ever BIGINT;
  v_recent BIGINT;
  v_precond BOOLEAN;
  v_alerts JSONB := '[]'::jsonb;
  v_audit public.raw_retention_audit;
BEGIN
  -- 1. TTL purge: STRICTLY older than 90 days, per row (fetched_at/created_at
  --    < cutoff keeps a row exactly 90.0 days old — the ratified boundary).
  DELETE FROM public.provider_raw_payloads WHERE fetched_at < v_cutoff;
  GET DIAGNOSTICS v_purged_prp = ROW_COUNT;

  DELETE FROM public.garmin_health_data
    WHERE data_type = ANY (v_garmin_raw_types) AND created_at < v_cutoff;
  GET DIAGNOSTICS v_purged_ghd = ROW_COUNT;

  -- 2. Sizes and counts.
  SELECT count(*) INTO v_count_prp FROM public.provider_raw_payloads;
  SELECT count(*) INTO v_count_ghd FROM public.garmin_health_data
    WHERE data_type = ANY (v_garmin_raw_types);
  -- Raw footprint: the dedicated table's full relation + the raw rows' stored
  -- payload bytes inside the shared garmin table (its non-raw rows are not
  -- retention-governed and must not count toward the 2 GB re-evaluation trip).
  SELECT pg_total_relation_size('public.provider_raw_payloads')
       + COALESCE((SELECT sum(pg_column_size(data)) FROM public.garmin_health_data
                    WHERE data_type = ANY (v_garmin_raw_types)), 0)
    INTO v_raw_bytes;
  v_db_bytes := pg_database_size(current_database());

  -- 3. Under-arrival flows: self-arm, then evaluate.
  FOR v_flow IN SELECT * FROM public.expected_flows LOOP
    IF v_flow.source_table = 'provider_raw_payloads' THEN
      SELECT count(*) INTO v_ever FROM public.provider_raw_payloads
        WHERE provider = v_flow.source_filter;
      SELECT count(*) INTO v_recent FROM public.provider_raw_payloads
        WHERE provider = v_flow.source_filter
          AND fetched_at >= p_now - v_flow.window_interval;
    ELSE
      SELECT count(*) INTO v_ever FROM public.garmin_health_data
        WHERE data_type = v_flow.source_filter;
      SELECT count(*) INTO v_recent FROM public.garmin_health_data
        WHERE data_type = v_flow.source_filter
          AND created_at >= p_now - v_flow.window_interval;
    END IF;

    IF v_flow.armed_at IS NULL THEN
      IF v_ever > 0 THEN
        UPDATE public.expected_flows SET armed_at = p_now
          WHERE flow = v_flow.flow;
      END IF;
      CONTINUE;  -- an unarmed flow never alerts, even on its arming sweep
    END IF;

    -- Precondition kinds. Never last_sync_status (W6: proven liar) —
    -- an active connection row is the only evidence consulted.
    IF v_flow.precondition LIKE 'active_integration:%' THEN
      SELECT EXISTS (SELECT 1 FROM public.integrations
        WHERE provider = split_part(v_flow.precondition, ':', 2)
          AND is_active) INTO v_precond;
    ELSIF v_flow.precondition = 'active_garmin' THEN
      SELECT EXISTS (SELECT 1 FROM public.garmin_user_mappings) INTO v_precond;
    ELSE
      v_precond := false;  -- unknown kind: never alert on a typo
    END IF;

    IF v_precond AND v_recent < v_flow.min_rows THEN
      v_alerts := v_alerts || to_jsonb(v_flow.flow);
    END IF;
  END LOOP;

  -- 4. The audit row (the dead-man clause watches its freshness from outside).
  INSERT INTO public.raw_retention_audit
    (swept_at, purged, row_counts, raw_total_bytes, db_total_bytes,
     oversize_alert, underarrival_alerts)
  VALUES (
    p_now,
    jsonb_build_object('provider_raw_payloads', v_purged_prp,
                       'garmin_health_data_raw', v_purged_ghd),
    jsonb_build_object('provider_raw_payloads', v_count_prp,
                       'garmin_health_data_raw', v_count_ghd),
    v_raw_bytes,
    v_db_bytes,
    (v_raw_bytes > 2147483648 OR v_db_bytes > (p_plan_bytes * 0.60)::BIGINT),
    v_alerts
  )
  RETURNING * INTO v_audit;

  RETURN v_audit;
END;
$$;

-- Sweep runs as the cron owner / service role only.
REVOKE EXECUTE ON FUNCTION public.raw_retention_sweep(TIMESTAMPTZ, BIGINT)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Schedule: daily, wall clock injected here and only here. Idempotent via
-- unschedule-if-exists. (Email notify wrapper arrives with the pg_net piece.)
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'raw-retention-sweep') THEN
    PERFORM cron.unschedule('raw-retention-sweep');
  END IF;
  PERFORM cron.schedule(
    'raw-retention-sweep',
    '17 3 * * *',  -- daily 03:17 UTC, off the top-of-hour herd
    $job$ SELECT public.raw_retention_sweep(now()); $job$
  );
END;
$$;
