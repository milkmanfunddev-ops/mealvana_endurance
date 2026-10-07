# 08: Cold start: leftover data, every tab, and every route-only screen

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:startup, read-only
**Branch:** `develop-next`
**Source:** testing-wave 29 (`origin/mealplanning`), plus the cold start the branch-split HANDOFF owes,
plus the routes that have no in-app entry on develop-next
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 08`
**Model:** opus

**What to test:** Three things, in order. (A) The first launch of a develop-next build on top of the
dev simulator's leftover data and database, which came from an older develop build. (B) A clean
sign-in where every tab and its first screen render with a clean console. (C) Every screen that has a
route but no button leading to it opens by deep link without an error.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/08/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** whatever the dev simulator copy is signed in as for part A (do not sign in or out before
A ends); the dev test account for B and C.

**App data:** NOT cleared. The wave lead skips `clear-app.sh` for this ticket and says so in the
prompt. This is the device check `.scratch/branch-split/HANDOFF.md` owes ("one cold start of a
develop-next build on the dev simulator with an account that ran develop's v21").

## Part A: leftover data

1. Before the first launch, read the app's Drift database read-only: find it with
   `xcrun simctl get_app_container UDID com.milkman.mealvanaendurance.dev data`, then
   `sqlite3 -readonly <container>/Documents/mealvana_endurance_db.sqlite 'PRAGMA user_version'` (the
   file name is in `lib/shared/database/connection_native.dart`; search the container if it moved).
   Record the version and the table list. Compare with `schemaVersion` in
   `lib/shared/database/app_database.dart` and the reasoning in the HANDOFF's "Drift" bullet: a v21
   device walks the v22 step and keeps its extra (Vana) tables; a v22 device skips the upgrade.
2. Launch with the console going to RUNS. Expected: no database reset, no `DriftRemoteException`, no
   "schema corrupted" (Sentry DEV-A6 is that failure), the signed-in account's data on the Timeline.
3. After launch, read `user_version` again. Record any `DatabaseReset` line (Sentry DEV-61/60).

## Part B: every tab

Sign out (Settings → Account), sign in with the dev test account. Then:

| Tab / surface | Code (from code, unverified) |
|---|---|
| Timeline (tab 0) | `lib/shared/widgets/tabs_screen.dart` → `MacroDashboardBody` |
| Events (tab 1) | `lib/features/events/presentation/screens/events_list_screen.dart` |
| Learn (tab 2), then play one lesson (`VideoPlayerScreen`) | `lib/features/education/presentation/screens/{education,video_player}_screen.dart` |
| Settings (gear in the header) | `lib/features/settings/presentation/screens/settings_screen.dart` |

Switch tabs quickly once (inside a second of sign-in: the earlier round's 29-004). Then one offline
cold start: `scripts/testing-wave/netcut/netcut.sh launch UDID SCRATCH`, `netcut.sh on SCRATCH
--relaunch UDID`. The Timeline renders from the local database and nothing crashes. `netcut.sh off`.

## Part C: route-only screens, by deep link

Nothing in `lib/` navigates to these routes on develop-next (grep of every route in
`lib/shared/core/app_router.dart` against every `push`/`go` call; from code, unverified). Open each with
`xcrun simctl openurl UDID "com.milkman.mealvanaendurance://<path>"`, screenshot it, press Back, read
the console. Do not submit anything; no AI call is made in this part.

| Path | Screen |
|---|---|
| `/pro` | `ProVersionScreen` (a "coming soon" page) |
| `/settings/sport-settings` | `SportSettingsScreen` (its only link is in the unmounted `SettingsMenuScreen`) |
| `/settings/food-preferences-consolidated` | `FoodSettingsConsolidatedScreen` |
| `/settings/food-preferences/add-food` | `AddFoodScreen` (barcode_scanning) |
| `/athlete/feedback` | `AthleteFeedbackScreen` |
| `/meal-log/manual`, `/meal-log/photo`, `/meal-log/describe`, `/meal-log/recent-saved`, `/meal-log/recipe` | the standalone meal-log screens |
| `/jade` | `AiCoachChatScreen` (its banner, `AiCoachBanner`, is mounted nowhere) |
| `/buy-credits` | `BuyCreditsScreen` |

For each: does it render, does Back return somewhere sane, and should an athlete be able to reach it?
The last question is for triage: a screen with no way in is an `idea` Finding (wire it or delete it),
except `/jade`: Lee's standing rule is that AI surfaces stay on for dev, so a Jade with no entry point
is a `bug` Finding.

## Expected records

Read only. `RUNS/expected.md` lists part A's before/after `user_version` and table lists.

## What counts as a Finding

- Every console error or exception line in A, B or C is a Finding or listed in notes as known noise
  with a reason. Expected noise on the dev test account: TrainingPeaks and V.O2 token Degradeds (its
  refresh tokens are dead, Sentry ticket 22); say so, do not file them again.
- A database reset, data loss or a startup hang in part A is a bug and stops part A (STOPPED.md names
  part B as the resume point).
- Look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/29-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 08 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-08-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-08`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/08-*.md` and `runs/08/` committed on the ticket branch, explicit paths only.
