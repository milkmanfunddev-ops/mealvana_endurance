-- Events refresh routine — operational tables (Phase 1 scaffolding).
--
-- Supports a scheduled routine that keeps public_events current by (a) rolling
-- recurring races over to their next occurrence and (b) discovering new races.
-- See docs/technical/data-refresh-routines.md.
--
-- Idempotent: CREATE TABLE / INDEX IF NOT EXISTS.

-- Per-run audit log (mirrors catalog_sync_runs for the feed).
CREATE TABLE IF NOT EXISTS public.events_refresh_runs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at    TIMESTAMPTZ,
  status          TEXT NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'completed', 'failed')),
  mode            TEXT CHECK (mode IN ('rollover', 'discovery', 'both')),
  buckets_swept   INT  NOT NULL DEFAULT 0,
  events_added    INT  NOT NULL DEFAULT 0,
  events_updated  INT  NOT NULL DEFAULT 0,
  events_flagged  INT  NOT NULL DEFAULT 0,   -- low-confidence / needs human
  errors          JSONB NOT NULL DEFAULT '[]'::jsonb,
  notes           TEXT
);

CREATE INDEX IF NOT EXISTS events_refresh_runs_started
  ON public.events_refresh_runs (started_at DESC);

-- Discovery coverage ledger: one row per (state, category) bucket. The routine
-- sweeps the stalest buckets each run (rotation) so a full sweep happens over a
-- cycle without an expensive nationwide search every run.
CREATE TABLE IF NOT EXISTS public.events_coverage (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_key       TEXT NOT NULL UNIQUE,        -- e.g. 'AL|marathon'
  state            TEXT NOT NULL,
  category         TEXT NOT NULL,               -- marathon, half_marathon, 5k, 10k, triathlon, ...
  last_swept_at    TIMESTAMPTZ,
  last_found_count INT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS events_coverage_staleness
  ON public.events_coverage (last_swept_at NULLS FIRST);
