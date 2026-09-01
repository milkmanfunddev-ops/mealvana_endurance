-- ---------------------------------------------------------------------------
--  PROD CUTOVER — STEP 4 of 4.  THE FORCE-UPDATE FLIP.
--
--  ⛔ DO NOT RUN THIS UNTIL 1.23.1 IS *APPROVED AND LIVE* ON BOTH STORES.
--
--  Not "submitted", not "in review", not "processing" -- downloadable. This
--  statement is what strands every older client on the force-upgrade screen,
--  and that screen's only exit is the store button. Running it while the
--  build is still in review bricks the installed base into a dead end: the
--  button opens a listing that still offers the OLD version, which installs
--  and is immediately rejected again.
--
--  Android is the tighter constraint. The prod Android track is Play OPEN
--  TESTING, and an open-testing release still has to clear Google review
--  AND be manually sent for review in the Play Console
--  (`changes_not_sent_for_review: true` in codemagic.yaml). Confirm the
--  release shows "Available to testers" before running this.
--
--  Idempotent. Safe to re-run.
-- ---------------------------------------------------------------------------

begin;

-- ── Minimum app version ────────────────────────────────────────────────────
-- Prod sat at 1.14.1 (set 2026-02-05). 1.23.1 is the first build that carries
-- BOTH halves of the coordinated release:
--   * Drift schemaVersion 17          (lib/shared/database/app_database.dart)
--   * the v3 time_window literals     (before_sub_phase.dart, pre-workout.ts)
-- Anything older reads the remapped catalog as empty meal/snack pools and
-- silently dumps the whole pre-workout budget into the top-off.
update public.app_config
set value = '1.23.1', updated_at = now()
where key = 'min_app_version';

-- ── Drift schema compatibility window ──────────────────────────────────────
-- Prod still advertises 14; the shipped client is 17. VersionCheckService
-- prefers latest_schema_version when the row exists, so both must move or the
-- clients keep negotiating against a version that no longer exists.
--
-- Bumping current_schema_version triggers a client delete-and-resync -- which
-- is the point here (local caches hold pre-workout plans built from the old
-- catalog), but it is also why this cannot run before the build is live.
update public.app_config
set value = '17', updated_at = now()
where key in ('current_schema_version', 'latest_schema_version');

-- min_supported_schema_version stays at 11. Do NOT raise it to 17 in the same
-- breath: it is the backend's floor for clients still draining their upload
-- queue, and lifting it drops unsynced local writes from anyone who has not
-- opened the app since the previous release.

-- ── Verify ─────────────────────────────────────────────────────────────────
do $$
declare r record;
begin
  for r in
    select key, value from public.app_config
    where key in ('min_app_version', 'current_schema_version',
                  'latest_schema_version', 'min_supported_schema_version')
    order by key
  loop
    raise notice 'app_config % = %', r.key, r.value;
  end loop;
end $$;

commit;
