# Agent brief — Phase C deploy of dashboard v2 + daily-macro engine v6.0.0 (2026-08-19)

You are executing the deploy Xuan runs by hand; you prepare, verify and document — **you do not deploy
to prod and you do not touch `app_config` on prod.** Read, in this order:

1. `ops/docs/supabase-deploy-playbook.md` — **§0 first** (current state + standing orders, added
   2026-08-20), then **§7** (the dev half is ✅ DONE; the remaining prod half is the **P1–P9**
   sequence), **§6** (versioning ruling — executed; floor gate now canon), **§4 steps 4–5**
   (app_config semantics; min_supported stays 17 at release). Ruling markers: **▶ Lee 08-20** wins
   over **▶ Lee 08-19** wins over older text **and over this brief** (this brief predates the 08-20
   sync — where they conflict, the playbook is right; known deltas: the CodeMagic integration-test
   ban and the `MACRO_DASHBOARD_ENABLED` removal are new standing orders). The rest of the playbook
   is narrative for Xuan — skim, don't act on it.
2. Repo truth you must still obey: `docs/deployment/README.md` (deploy scripts, project refs, `_shared`
   redeploy rule), `supabase/migrations/README.md` (hand-applied SQL, never `db push`),
   `supabase/functions/TESTING.md` (runner, `--e2e` needs a deployed target),
   `docs/ssot/bundles/daily-macros-dashboard.handoff.md` (`@v3` contract; vectors are never edited to pass).
   Where the playbook and a repo doc conflict, the playbook's ▶ marker tells you which way Lee ruled;
   do not rewrite repo docs from the playbook except the one README change below.

## Decisions already made — do not reopen
- **New function name, not an in-place overwrite — and shape the repo so the names can't drift.** The
  client pins `_expectedAlgorithmVersion = 'v5.0.0'`
  (`lib/features/daily_macros/data/daily_macro_targets_repository.dart:47`) and discards cached days
  on mismatch; the engine emits `v6.0.0`. The folder `supabase/functions/calculate-daily-macros/`
  currently holds the **v6** source while the **deployed** `calculate-daily-macros` is **v5** and must
  stay v5 for old installs. Do this:
  1. `git mv supabase/functions/calculate-daily-macros supabase/functions/calculate-daily-macros-v6`
     (v6 source + its vectors/conformance tests move with it; `-vN` matches `generate-macros-v4` /
     `generate-nutrition-plan-v3` and the payload's `algorithm_version`).
  2. Recreate `supabase/functions/calculate-daily-macros/` as a **frozen v5 snapshot** from
     `origin/develop` (`git checkout origin/develop -- supabase/functions/calculate-daily-macros`),
     **without its test files** (archive those to `_archived/supabase/functions/calculate-daily-macros/`),
     plus a `README.md` ("LEGACY v5 — deployed for clients expecting algorithm_version v5.0.0; do not
     edit; redeploy only to roll back; delete when `min_supported_schema_version ≥ 18`") and an empty
     `FROZEN` marker file.
  3. Check the frozen folder's `_shared` imports against the branch's `_shared` changes
     (`garmin/activity_completion.ts`, `workouts/*`); if any changed incompatibly, vendor what v5 needs
     into the frozen folder so a rollback redeploy is self-contained.
  4. Guard the wrappers: in `scripts/deploy_dev.sh` and `deploy_prod.sh`, if
     `supabase/functions/<fn>/FROZEN` exists, refuse unless `--force-legacy` is passed (rollback only).
  5. Point `daily_macro_service.dart` (both call sites, ~L200 and ~L444) at `calculate-daily-macros-v6`,
     and **relax the client gate in this build** so future engine bumps can overwrite in place: accept
     any `algorithm_version` (or `>=`), invalidate only on schema change; one-line comment why.
  6. Update `docs/deployment/README.md` (app-invoked list: add `-v6`, mark `calculate-daily-macros`
     LEGACY/frozen) and `supabase/functions/EDGE_FUNCTION_AUDIT.md` if it enumerates functions.
- **Migrations:** apply `supabase/migrations/20260814120000_activities_two_time_and_tombstone.sql` and
  `20260814121000_plan_recalc_log.sql` **one file at a time, by hand, in DataGrip** (Xuan runs it — you
  hand him the exact paste + the verification queries). Loosen `supabase/migrations/README.md` so loose
  timestamped files are allowed alongside the apply-all flow; never run `supabase db push`.
- **Edge functions to deploy to dev (4):** `calculate-daily-macros-v6 garmin-push garmin-ping
  sync-all-data` via `./scripts/deploy_dev.sh …` (they import the changed `_shared` modules). **Not**
  `calculate-daily-macros` — it stays v5, frozen. Verify with `supabase functions list --project-ref vlmtsdzpnjnavdgytcmi`
  and, once, `supabase functions download` + diff.
- **app_config on dev this round:** set `current_schema_version` (and `latest_schema_version` if the row
  exists) to `18`; **do not** change `min_supported_schema_version` or `min_app_version`. Nothing on prod.
- **No local Supabase / Docker.** Local engine proof = `bash supabase/functions/run-algorithm-tests.sh`
  (172 vectors green); integration (`--e2e`, Patrol remote half) only after the dev deploy.
- **Tests:** move the four legacy `calculate-daily-macros` test files to `_archived/supabase/functions/…`
  (auto-discovery; do not rename in place). Do not edit vectors or specs to make anything pass.
- **No cron jobs, triggers or stored functions** exist on Supabase that call the engine; onboarding's
  preview calc is local Dart — leave both alone.

## Hand back to Xuan
A short checklist (commands + expected output) for steps 1, 4, 5, 10 of playbook §7, the DataGrip paste
for the two migrations with verification SQL, the `functions list` before/after, and the diff of the
client changes (new function name + relaxed gate), plus the `git mv` / frozen-snapshot layout and the `FROZEN` guard diff. Flag anything that contradicts the above instead of
working around it. Prod steps (7–11) are a later, separate hand-off — do not prepare them now.
