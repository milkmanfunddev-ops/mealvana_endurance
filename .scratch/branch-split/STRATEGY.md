# Branch split: develop without meal planning, mealplanning with everything (research, 2026-10-06)

Status: PROPOSAL, nothing executed. Measured in throwaway worktrees by two Opus research agents; numbers below are
from dry runs against `origin/*` as of 2026-10-06 (`origin/develop fb4a97e9`, `origin/mealplanning aec125f7`,
`origin/release/1.29.0`, local `sentry 50c472b3`).

## What is actually true

1. **Meal planning entered `develop` through ONE merge:** `f71694ba` (2026-09-06, "Merge mealplanning into develop —
   phases 1-8 + Pro gate"), 48 commits, 591 files added. The 09-01 "Phase 4a/4b" merges are inside it. Four later
   Xuan commits touch meal-planning files (`14e895bf`, `1e7b34e6`, `d24d8f18`, `2014fd90`) plus `0ecf6b4a` (Patrol
   meal-plan flows). Footprint today: 208 files under `lib|test/features/meal_planning`, 13+7 subscription/Pro-gate
   files, Drift tables `meal_plans`, `plan_meals`, `user_entitlements`, `user_memories`, edge functions `vana-action`,
   `vana-chat`, `vana-day-notes` (+ `_shared`, and edits to `jade-chat` / `revenuecat-webhook`), 12 migrations
   (20260827–20260903), routes `/food` and `/vana`, pubspec `wakelock_plus`, `vibration`, `share_plus`.
2. **Nothing meal-planning has ever shipped.** `release/1.26.0` … `release/1.29.0` and `main` all lack `f71694ba`
   and have zero meal-planning files. Only dev-build devices ran it.
3. **Xuan's source of truth is the `release/*` line, not `develop`.** She works on `release/1.29.0` + `fix/*` and
   syncs commits onto develop ("chore: sync the seven 1.29.0 commits onto develop"). Release/1.29.0 already holds
   nearly all of her work: of develop's 152 commits since release/1.29.0, 39 are patch-equivalent to release commits,
   39 are meal planning, 70 are Xuan's non-meal-planning, 4 Xuan-touching-meal-planning. Release has 39 commits
   develop lacks, 35 patch-equivalent; the 4 `fix/*1.29*` branches add nothing beyond release.
   **So a "develop without meal planning" already exists: it is `release/1.29.0` + 27 files of genuinely
   develop-only Xuan content** (events date fix, dashboard transient telemetry, Garmin sample capture, macros-v6,
   shorebird docs).
4. **Drift schema is the hard constraint.**
   | version | develop | release/1.29.0 | mealplanning (v24) |
   |---|---|---|---|
   | v21 | Vana tables + meal_logs/saved_meals columns | EMPTY placeholder ("develop owns v21") | Vana |
   | v22 | `activities.duration_source` | same | `users.home_*` (+ re-adds), NO `duration_source` |
   | v23/24 | – | – | `activities.completion_type` / `meal_logs.servings` |
   develop can never go below v22. mealplanning's v22 means something different from develop's v22: a device that ran
   a 1.29.0 build (v22) then installs a mealplanning build only runs 23–24 and never gets `home_*`; a mealplanning build
   never adds `duration_source`. Two migrations share timestamp `20260901160000` (meal_image_licensing vs Xuan's
   catalog_conventions).
5. **Dry-run costs.**
   - Revert `f71694ba` on develop: 25 conflicting files (app_database + .g, pubspec, tabs_screen,
     app_startup_service, notification_service, 7 `.g.dart`, schema snapshots, v21 migration tests, schema guard).
   - Rebuild develop = release/1.29.0 + Xuan's 70 develop-only commits: 43 clean, 25 conflicts (release already has
     the equivalent; take Xuan's side), 2 fail (`0ecf6b4a` Patrol meal-plan flows: drop; `a6b7cf3d` schema v19 json:
     regenerate).
   - Sentry's 57 non-merge commits onto that base: 21 conflicting commits = 59 delete/modify in meal-planning /
     subscription / vana files (they just drop) + 26 shared files (`main*.dart`, `app_router`, `tabs_screen`,
     `pubspec.lock`, `jade-chat`, `revenuecat-webhook`, `content_service`, `saved_meal(s)`, `ai_coach_chat_repository`,
     `settings_controller`, `allow_list.md` ×8, `events_service`+test, auth ×2, `daily_macros` ×2,
     `integrations_providers`, `expected_failures`, 2 sync tests, shorebird docs).
   - `sentry` → `mealplanning` merge (base `e323f238`, 1,170 commits apart): 124 conflicting files (21 meal_planning,
     9 meal_logging, 8 `_shared`, 8 auth, 7 integrations, `app_database`, `app_router`, `tabs_screen`, pubspec;
     add/add `CONTEXT.md` + `.scratch/ssot/review-queue.md`; modify/delete: mealplanning deleted `ai-coach`,
     `coach_insight_controller`, `ai_coach_client`, `insufficient_credits_paywall` that sentry edits; sentry deleted
     `sentry_event_filter`+test and two `Package.resolved` that mealplanning edits).

## Two ways to do it

**V — revert the merge on develop.** One `git revert -m 1 f71694ba` + 25 hand-resolved files; v21 becomes the empty
step release already has; no force push. BUT develop's history then contains "add meal planning" + "remove meal
planning". Any future `git merge develop` into mealplanning would DELETE meal planning there (you would have to revert
the revert first, against 1,170 commits of drift). mealplanning would have to take Xuan's work from `release/*`
forever and never from develop. That is the out-of-sync trap you asked to avoid.

**R — rebuild develop from the release line (recommended).** New branch from `origin/release/1.29.0`; cherry-pick
Xuan's 70 develop-only commits (27 conflicts, mostly "already there"); verify the 27-file real gap; keep v22 with
release's empty v21; then rebase the Sentry work onto it (59 hunks drop, 26 shared files to resolve). Replace
`develop` with it (`push --force-with-lease`, one push, cuts a dev build). develop's history never contained meal
planning, so `git merge develop` into mealplanning is safe forever, and develop == Xuan's lineage + Sentry, which is
how she already treats it. Cost: one force push that Xuan must know about (she resets her local develop; her release
and fix branches are untouched), and ~two sessions of conflict work.

## Sequence for R

1. **Agree with Xuan** (before anything): develop will be rebuilt from release/1.29.0; she pushes whatever is
   unpushed; after the force push she `git fetch && git reset --hard origin/develop`. Her `release/*`/`fix/*` flow is
   unchanged. No pushes to develop by anyone in between.
2. **Build `develop-next`** in a worktree: `git checkout -b develop-next origin/release/1.29.0`; cherry-pick the 70
   (list from `git log origin/release/1.29.0..origin/develop --no-merges --cherry-pick --right-only`, minus the 39
   meal-planning shas and `0ecf6b4a`); regenerate `drift_schema_v19.json`; `flutter test` full + `flutter analyze`;
   diff against develop restricted to non-meal-planning paths must be ~empty.
3. **Sentry onto develop-next**: `git rebase --onto develop-next 6e969e77 sentry` as branch `sentry-next` (resolve the
   26 shared files, let the 59 meal-planning hunks drop, the allow-list conflicts are the usual both-deletions
   pattern); source guard + full suite + `/code-review` since develop-next. Fast-forward develop-next to it.
4. **Replace develop:** `git push --force-with-lease=develop:fb4a97e9 origin develop-next:develop` (Lee's go; cuts
   the dev TestFlight build). Tag the old tip first: `git tag develop-pre-split fb4a97e9 && git push origin
   develop-pre-split` so nothing is lost.
5. **mealplanning gets everything:** merge the ORIGINAL `sentry` branch (it carries the meal-planning Report
   migration, ~45 files / 1,347 lines, which `sentry-next` dropped) → 124 conflicts, areas above; then cherry-pick
   Xuan's two newest develop commits (`b25a122a`, `fb4a97e9`) and anything on release/1.29.0 not yet in mealplanning
   (`git log mealplanning..origin/release/1.29.0`). Then **Drift fix on mealplanning**: add `activities.duration_source`
   as v25 (mealplanning builds at v24 lack it), and record in `docs/implement_mealplanning/06` cutover runbook that at
   the eventual mealplanning→develop merge its v22/23/24 steps must be renumbered above develop's v22 and v21 must stay
   empty. Full suite, deploy nothing to prod.
   From then on: `git merge develop` into mealplanning weekly (safe under R), never the other way until cutover.
6. **Round-up testing on develop** (see below), fix, Sentry clean, then the final push to develop.

## Round-up testing (the testing-wave)

Lives ONLY on `mealplanning`: `.scratch/testing-wave/` (RUNBOOK.md, spec.md, IMPROVEMENTS.md with 90 entries,
findings/ one file per Finding via `scripts/testing-wave/findings.mjs` → `findings/INDEX.md`, retest-drafts/ 143–161
= the "extra coverage run", AUTORUN.md + autorun-log.md) and `scripts/testing-wave/{lock,cost,findings,state,cred}.mjs`,
`clear-app.sh`, `app-build.json`; simulator pool via `docs/ssot/decisions/_page/sync.mjs simulator claim`; skill
`.claude/skills/implement-lee`. Totals: 145 tickets (59 test, 86 fix), 556 Findings (230 bugs, 235 follow-ups, 77
ideas, 14 SSOT conflicts; 337 triaged / 183 closed / 36 wontfix); last wave 44 closed 10-05; last simulator waves
39/40 on 09-26; Lee's 09-28 ruling "no more retests" leaves 147 fixed bugs unconfirmed on a device.
To run it on develop: cherry-pick the harness commits (scripts + RUNBOOK/spec/IMPROVEMENTS/TEMPLATE, not the tickets
or findings) onto develop-next; write a develop ticket set from tickets 01–32 minus Plans/Vana (14–18), Shopping/Kroger
(19–22) and the paywall-only ones, plus the Sentry debug-console probes as a ticket; agents claim one simulator each,
file Findings, lead triages in the terminal; exit criterion = Findings triaged to fix tickets AND both Sentry projects
show no unresolved issue from the new build's release tag.

## Sentry: what is still open (as of this write-up)

Prod: 3 (BP, C2 Play pre-launch emulator crashes; B7 watchdog false positive) — left open on purpose, with comments.
Dev: 49. The earlier triage pulled the first 100 of a longer list, so ~25 older issues (Sept 7–16: DEV-47, 6Y, 82,
4W, 61, 60, 7K, 70/6W/85/84 cancelled logins, 6P, 83, 8K, 86, 7Z, 7X/7Y/8A/8B, 7V, 8D) were never ticketed. Plus
DEV-4 (a catch-all: the old reporter grouped EVERY PostgrestException into one issue — 307 events = 26 qa-seed uuid,
12 user_entitlements column, 5 duration_source column, 4 integrations FK, 1 RLS; it will split by type once a
Report-era build runs), DEV-A2 (users RLS), 8G, 9H (Test Store simulated failure), 99, and by-design warnings
(8Y/8Z AI cost, 9B retention sweep, A5–A9 typed Degraded, AB cooldown). Proposed: ticket 26 "dev leftovers" to walk
those 49 the same way (root cause, fix or reasoned Degraded, resolvedInNextRelease), run AFTER the branch split so it
is done once against develop-next, and the known-red `ci_config_contract_test` fixed or deleted.
