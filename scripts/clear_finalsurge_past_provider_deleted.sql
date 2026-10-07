-- Ticket 42 (testing-wave, Finding 30-001): the FinalSurge sync fetched
-- upcoming workouts only and flagged every local FinalSurge row that had
-- fallen out of that window as deleted upstream, one day after it happened.
--
-- This clears those flags. A row is "wrongly flagged" when its scheduled day
-- is earlier than the day it was flagged: the sync could not have seen it in
-- an upcoming-only fetch. provider_deleted_at was written as the device's
-- local wall clock labelled UTC (Finding 30-002), so `AT TIME ZONE 'UTC'`
-- recovers that local date. Rows flagged on or before their scheduled day
-- were inside the window and are left alone (11 rows on dev, 2026-09-25).
--
-- updated_at is bumped so a phone's pull (ActivitySyncHandler.upsertActivity
-- takes the server row only when its updated_at is newer) replaces the stale
-- local flag. The column is `timestamp without time zone`; CURRENT_TIMESTAMP
-- matches its default.
--
-- Idempotent: a second run matches zero rows. Run on DEV only
-- (vlmtsdzpnjnavdgytcmi) via the Management API `database/query`;
-- run 2026-09-25 by ticket 42: 213 rows before, 0 after.

-- 1. Read first: what would change.
SELECT status::text AS status, count(*) AS rows,
       min(scheduled_date_time) AS earliest, max(scheduled_date_time) AS latest,
       count(DISTINCT user_id) AS users
FROM activities
WHERE synced_from_provider = 'final_surge'
  AND provider_deleted_at IS NOT NULL
  AND deleted_at IS NULL
  AND scheduled_date_time::date < (provider_deleted_at AT TIME ZONE 'UTC')::date
GROUP BY 1;

-- 2. Clear the wrongly flagged rows.
UPDATE activities
SET provider_deleted_at = NULL,
    updated_at = CURRENT_TIMESTAMP
WHERE synced_from_provider = 'final_surge'
  AND provider_deleted_at IS NOT NULL
  AND deleted_at IS NULL
  AND scheduled_date_time::date < (provider_deleted_at AT TIME ZONE 'UTC')::date;

-- 3. Verify: expect 0.
SELECT count(*) AS still_wrongly_flagged
FROM activities
WHERE synced_from_provider = 'final_surge'
  AND provider_deleted_at IS NOT NULL
  AND deleted_at IS NULL
  AND scheduled_date_time::date < (provider_deleted_at AT TIME ZONE 'UTC')::date;
