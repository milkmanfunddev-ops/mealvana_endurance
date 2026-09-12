-- Q-INT25 hygiene batch (data-integrations@v1 Stage D tail; matching.md M-6
-- adequacy rows). Rehearsed on a prod-schema shadow with BOTH brick
-- casings seeded and per-casing before/after row counts asserted (test
-- plan §4) before any dev/prod apply.

-- 1. RECORD the enum values the live schema depends on (M-6.3: 'draft' was
--    in the matcher filters with no migration adding it — an unrecorded
--    manual edit; M-6.5: the brick schema lived only in an _archived
--    migration). Idempotent adds make the live migration set reproduce the
--    running schema. 'transition' is DELIBERATELY not added: B-4 rules that
--    transitions never become rows, so no enum value may exist to write.
DO $$ BEGIN
  ALTER TYPE activity_status_enum ADD VALUE IF NOT EXISTS 'draft';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TYPE activity_status_enum ADD VALUE IF NOT EXISTS 'archivedForBrick';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TYPE activity_type_enum ADD VALUE IF NOT EXISTS 'brick';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS brick_metadata jsonb;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS brick_id text;

-- 2. Enum-casing unification (M-6.4, the audit-flagged failed rename):
--    'archivedForBrick' is CANONICAL — it is what the Dart writer emits
--    (ActivityStatus.archivedForBrick.name). Live 'archived_for_brick'
--    rows move to it. The spare enum VALUE stays (dropping enum values is
--    a table-rewrite affair, deliberately out of scope); consumers may
--    stop testing both casings once this has applied everywhere.
UPDATE public.activities
SET status = 'archivedForBrick'
WHERE status = 'archived_for_brick';

-- 3. Q-INT10: the last_sync_status CHECK must include 'requires_reauth'
--    (dev already carries it; prod's is narrower). Idempotent re-create.
ALTER TABLE public.integrations
  DROP CONSTRAINT IF EXISTS integrations_last_sync_status_check;
ALTER TABLE public.integrations
  ADD CONSTRAINT integrations_last_sync_status_check
  CHECK (last_sync_status IS NULL OR last_sync_status = ANY (ARRAY[
    'success'::text, 'error'::text, 'pending'::text, 'requires_reauth'::text
  ]));

-- 4. Dead columns (M-6 / P-4.2 — zero readers, zero writers, verified
--    against the SHIPPED 1.26.0 client's payloads before dropping):
--    activities.tss retires now that tss_planned/tss_actual exist; the
--    activities-table FTP/CSS/speed orphans go (the LIVE users.* twins are
--    untouched); integrations.threshold_pace_min_per_mile and the
--    never-read users.prefers_* pair go.
ALTER TABLE public.activities
  DROP COLUMN IF EXISTS tss,
  DROP COLUMN IF EXISTS cycling_ftp_watts,
  DROP COLUMN IF EXISTS swimming_css_seconds_per_100m,
  DROP COLUMN IF EXISTS swimming_speed_per_100m;
ALTER TABLE public.integrations
  DROP COLUMN IF EXISTS threshold_pace_min_per_mile;
ALTER TABLE public.users
  DROP COLUMN IF EXISTS prefers_cycling_power,
  DROP COLUMN IF EXISTS prefers_swimming_pace;
