-- provider_raw_payloads — raw FS/TP payload retention (real-payload-corpus@v1)
--
-- Contract: qa spec/integrations/lifecycle.md L-7 (RULED Xuan 2026-09-20) +
-- vectors/integrations/raw-retention.json. One row per (provider workout id,
-- LastModifiedDate): a re-fetch with an unchanged last_modified writes NOTHING
-- (client inserts with on-conflict-do-nothing); an edit (changed last_modified)
-- INSERTS a new versioned row — history is never replaced. TTL: the sweep purges
-- rows STRICTLY older than 90 days by each row's own fetched_at (a row exactly
-- 90.0 days old is retained — ratified boundary convention).
--
-- Separate table, never a column on activities: TTL lifecycle differs, unmatched
-- payloads must be kept, and activities syncs to devices.
--
-- last_modified is the provider's value VERBATIM (text, not timestamptz):
-- provider timestamps are naive local wall-clock (lifecycle.md L-9), and this
-- column is an identity token, never arithmetic input. Providers without a
-- last-modified concept store '' (one version per workout id).
-- TTL arithmetic uses fetched_at, which is OUR clock.

CREATE TABLE IF NOT EXISTS public.provider_raw_payloads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- W2: delete-user relies purely on FK CASCADE; without this the table becomes
  -- the next orphan surface (Q-INT7's lesson).
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('final_surge', 'training_peaks')),
  provider_workout_id TEXT NOT NULL,
  last_modified TEXT NOT NULL DEFAULT '',
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- The versioning identity. A full unique constraint (not a partial index), so
  -- PostgREST on_conflict targeting it is safe (repo 42P10 rule).
  CONSTRAINT provider_raw_payloads_version_key
    UNIQUE (user_id, provider, provider_workout_id, last_modified)
);

COMMENT ON TABLE public.provider_raw_payloads IS
  'Raw FS/TP provider payloads, 90-day TTL (lifecycle.md L-7). One row per '
  '(workout id, last_modified); re-fetch with unchanged last_modified writes '
  'nothing; edits insert versioned rows. Fed by the client sync upload.';

-- TTL sweep scan: purge WHERE fetched_at < now() - interval '90 days'
CREATE INDEX IF NOT EXISTS idx_provider_raw_payloads_fetched_at
  ON public.provider_raw_payloads (fetched_at);

-- W4: replicate garmin_health_data's verified posture (RLS enabled, owner
-- SELECT, service-role ALL) + owner INSERT because this table is fed by the
-- phone during sync (garmin_health_data is fed by service-role edge functions,
-- so it carries no client INSERT policy).
ALTER TABLE public.provider_raw_payloads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own raw payloads" ON public.provider_raw_payloads;
CREATE POLICY "Users can view own raw payloads"
  ON public.provider_raw_payloads FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

-- Append-only from the client: INSERT but no UPDATE/DELETE policy — exemplars
-- are frozen and the purge runs service-side.
DROP POLICY IF EXISTS "Users can insert own raw payloads" ON public.provider_raw_payloads;
CREATE POLICY "Users can insert own raw payloads"
  ON public.provider_raw_payloads FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Service role full access on provider_raw_payloads" ON public.provider_raw_payloads;
CREATE POLICY "Service role full access on provider_raw_payloads"
  ON public.provider_raw_payloads FOR ALL
  USING ((SELECT auth.role()) = 'service_role');
