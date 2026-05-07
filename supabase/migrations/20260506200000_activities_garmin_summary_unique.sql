-- Enforce idempotent inserts of Garmin-pushed activities.
--
-- Background: garmin-push and garmin-ping previously only updated existing
-- planned activities. We now also INSERT a new completed activity when an
-- endurance Garmin upload has no matching planned activity. Because Garmin
-- often fires the Activities and ActivityDetails webhooks for the same
-- workout simultaneously (and sometimes retries), we need a database-level
-- guarantee that the same Garmin summaryId can't produce two activity rows
-- for the same user.
--
-- We use a regular UNIQUE INDEX (not partial) so PostgREST's onConflict can
-- still infer it cleanly if anyone later switches to .upsert(). NULLs are
-- treated as distinct under default settings, so non-Garmin activities
-- (garmin_summary_id IS NULL) are unaffected — multiple NULLs are allowed
-- per user.
--
-- The prior partial index idx_activities_user_garmin_summary served the
-- same lookup pattern; the new UNIQUE INDEX provides equivalent lookup
-- coverage (B-tree on (user_id, garmin_summary_id)) so we drop the old one.

-- ---------------------------------------------------------------------------
-- Step 1 — scrub bad data before adding the unique constraint.
--
-- The activityDetails matched-update branches in garmin-push and garmin-ping
-- previously called String(summary.summaryId) without first checking that
-- summary.summaryId was defined. Garmin occasionally sends ActivityDetails
-- payloads without a top-level summaryId, so the literal string "undefined"
-- got written into garmin_summary_id and broke uniqueness. Both call sites
-- are now guarded — but legacy rows still carry the bad value.
--
-- Restoring those rows to NULL is correct: the value carries no real Garmin
-- linkage. Subsequent Garmin pushes for the same workout (with a real
-- summaryId) will set it properly via the manuallyUpdatedActivities path or
-- the unique-constraint-protected insert path.
-- ---------------------------------------------------------------------------
UPDATE activities
   SET garmin_summary_id = NULL
 WHERE garmin_summary_id IN ('undefined', 'null', '');

DROP INDEX IF EXISTS idx_activities_user_garmin_summary;

CREATE UNIQUE INDEX IF NOT EXISTS activities_user_garmin_summary_id_key
  ON activities (user_id, garmin_summary_id);
