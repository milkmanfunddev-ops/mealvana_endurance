# 33: Retest: cross-device and leftovers

**Status:** ready (round develop-2026-10, retest)
**Labels:** retest, round:develop-2026-10, area:sync
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after the fix wave lands)
**Source:** TRIAGE.md rulings of 2026-10-07: followups 08-024 (cross-device meal visibility) and 01-012
(what a deleted account leaves on the device)
**Blocked by:** the fix wave (tickets 21–29) and its rebuild; runs in wave 3
**Next:** `/testing-wave develop-2026-10 --only 33`
**Model:** opus

**What to test:** (A) What a deleted account leaves behind on the device: prefs keys and Drift rows after
Delete Account, and whether the next user on the device sees any of it. (B) When a meal logged on one
device shows on another device signed in as the same account, and which action brings it.

**Two simulators.** This ticket needs TWO: the lead claims `testing-wave-33a` and `testing-wave-33b`
(`SIM claim` each, `clear-app.sh` on each), and the prompt names both udids (`UDID_A`, `UDID_B`). Both count
toward the cap of three, so 33 runs beside at most one other ticket. Part A uses only 33a. One run slot.

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/33/`,
Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. Two consoles (`console-a.log`,
`console-b.log`, one log stream per simulator, each PID in its own SCRATCH file). A look-around on every
screen, every problem a Finding, nothing fixed. With two simulators up, never trust the mobile MCP's element
list for which screen it read (#39): use `idb ui describe-all --udid` and `simctl io <udid> screenshot`.

**Accounts:**
- Part A: two new accounts, `lee+e2e-33-<UTC time>@rightpathprogramming.com` (made with `CRED new`), both
  deleted by the run in the app.
- Part B: the dev test account (`CRED type test@test.com --udid <udid>`) on both simulators. This run writes
  two manual `meal_logs` rows on it and deletes both before the end. Tickets 31 (logs and deletes its own
  described meals) and 32 (read-only) use the same account in this wave: check only rows this run wrote,
  by `created_at` in the run's minutes and the food names you chose.

**App data:** cleared by the wave lead on both simulators.

**Cost:** no AI call. Meals are logged manually (Manual or Common in the Log a meal sheet: read which one
writes a `meal_logs` row without an AI call before choosing).

**Retest rule.** These are followups, so a check that completes with the expected result closes its
Finding: write `PASS <id>` in `RUNS/notes.md` with the evidence; the lead marks it `closed`. A check that
finds a problem files a new Finding with `findings.mjs new 33 … --round develop-2026-10` citing the old id
(`Retest of 08-024` / `Retest of 01-012`).

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Welcome, onboarding, Create account, Verify your email | as ticket 30 | `lib/features/onboarding/…`, `lib/features/auth/…` |
| Timeline, "+ Add Food", Log a meal sheet (Manual / Common) | `/main` | `lib/shared/widgets/tabs_screen.dart`, `lib/features/meal_logging/presentation/screens/log_meal_screen.dart` |
| New activity | Timeline | `lib/features/nutrition_plan/presentation/screens/new_activity_screen.dart` (check the path) |
| Settings → Account → Delete Account | gear | `lib/features/settings/presentation/providers/settings_controller.dart` `deleteAccount` |

## What the code clears on delete (from code, unverified; the device decides)

`SettingsController.deleteAccount()` calls `delete-user`, then `diagnosticDao.clearUserScopedData(userId,
forceDelete: true)`, removes the prefs keys `onboarding_temp_user_id` and `onboarding_snapshot_v1`, and
signs out. `clearUserScopedData` deletes this user's rows from: `carb_loading_day_meals`,
`carb_loading_days`, `carb_loading_plans`, `events`, `activities`, `carb_loading_user_foods`, `user_foods`,
`feedback` (via `device_id`), `food_preferences`, `integrations`, and the `user_profiles` row. It does not
name `meal_logs`, `saved_meals`, `daily_macro_targets`, `onboarding_surveys`, `race_checklist_items`,
`tp_writeback`, `personal_templates`, `formula_pins`, `personal_formulas`, the coach tables or the pairing
code tables. Prefs keys written per user or per repository that nothing in delete removes:

- `last_sync_timestamp_<user id>` (`lib/shared/services/sync/data_sync_service.dart`; seen after delete in
  01-012's run)
- `garmin_backfill_last_at_<user id>` (`connect_training_controller.dart`)
- `<repository>_last_sync`, e.g. `meal_logs_last_sync`, NOT keyed by user (`lib/shared/data/syncable_repository.dart`),
  and `integration_<provider>_last_sync` (`integration_sync_coordinator.dart`)
- `macro_targets.cached`, `macro_targets.original`, `macro_targets.cached.activity.*`, not keyed by user
  (`lib/features/nutrition_plan/data/macro_repository.dart`)
- `credits_ensured_stamp` (value `<user id>|<YYYY-MM>`), `has_completed_initial_survey`, `tp_writeback_*`,
  `fuel_tracking_enabled`, `privacy_*`, `analytics_consent_*` (device-wide by design; record, do not judge
  alone)

## Expected records (`RUNS/expected.md`)

- Part A: after delete, no Drift row anywhere keyed to the deleted id, and no prefs key or value naming it;
  `sweep-accounts.mjs footprint <id>` reports no server rows. The second user starts empty on screen. Every
  item that stays is listed with its table or key; whether it matters is judged by whether the next user
  can see or inherit it.
- Part B: one `meal_logs` row per manual meal, then `is_deleted` true after the delete. The question is
  when device B shows it, not whether the server has it.

## Part A: leftovers after delete (01-012), on 33a

How to read the device without printing secrets:
- Drift: `C=$(xcrun simctl get_app_container UDID_A com.milkman.mealvanaendurance.dev data)`, then
  `sqlite3 -readonly "$C/Documents/mealvana_endurance_db.sqlite"` (search the container if the file moved).
  For every table in `sqlite_master` that has a `user_id` column (`pragma table_info`), count rows
  `WHERE user_id = '<id>'`; plus `user_profiles WHERE id = '<id>'`. Counts only, no row contents.
- Prefs: terminate the app first (so the plist is flushed), then python `plistlib` on
  `$C/Library/Preferences/com.milkman.mealvanaendurance.dev.plist`: print key names, and print a value
  only for keys that are not auth, session or token keys and only to check whether it contains the user
  id (print "contains id: yes/no", never the value). The file holds the session token.

1. `CRED new` user 1, sign up on 33a (onboarding with run + bike). Record the id.
2. Write a footprint through the app: log one manual meal, create one activity, save a food preference.
3. Terminate; read the Drift counts and the prefs key list (before). Relaunch.
4. Settings → Account → Delete Account → Delete. Land on Welcome. Terminate; read both again (after).
   `footprint <id>` on the server. Diff before and after; every row or key still naming user 1 goes in
   `RUNS/leftovers.md` with its table or key.
5. `CRED new` user 2, sign up on 33a. On the Timeline, Settings and the Log a meal sheet's Recent tab:
   nothing of user 1 (meal, activity, targets, name, food preference). Compare the targets shown with what
   user 2's onboarding answers give; targets that match user 1's are a bug (the macro cache is device-wide).
6. Delete user 2 the same way; `CRED update` both as `deleted`.
7. Judge: a leftover the next user can see or inherit is a bug Finding; a leftover nobody reads is one
   `idea` Finding listing them all, citing 01-012.

## Part B: a meal logged on device A shows on device B (08-024)

From code, unverified: meal logs sync down through `SyncCoordinator.ensureSynced('meal_logs')`, which
skips the fetch while `meal_logs_last_sync` is under an hour old (`SyncableRepository.staleDuration`);
the Timeline has no pull-to-refresh (no `RefreshIndicator` under `macro_dashboard`); opening the Log a meal
sheet calls `ensureSynced`; there is no realtime channel on `meal_logs`. So the expectation going in is
that B may not show A's meal for up to an hour. The run measures it; it does not assume it.

1. Sign in as the test account on both simulators. Both on the Timeline, today. Note B's last
   `meal_logs` sync time (console `Successfully synced meal logs` line).
2. Meal 1: on A, log a manual meal into the current slot ("33 cross-device 1: apple"). Record T0 (UTC) and
   the row (SQL).
3. On B, try each action in this order, stopping at the first that shows meal 1; screenshot and clock time
   after each:
   (a) stay on the Timeline 2 minutes, one screenshot every 30 s;
   (b) switch to Events and back to the Timeline;
   (c) pull down on the Timeline (records whether any refresh exists);
   (d) open "+ Add Food" and close it (the sheet's `ensureSynced`);
   (e) background 30 s and resume;
   (f) terminate and relaunch;
   (g) leave B on the Timeline and check every 5 minutes up to 60 minutes after B's last sync, or until the
       run must end; write "not seen live" if the hour does not pass.
4. Meal 2: log a second manual meal on A ("33 cross-device 2: banana"). On B, go straight to the action that
   brought meal 1 and confirm it brings meal 2 too (same rule, not chance).
5. Delete both meals on A. On B, repeat that action: both cards gone (tombstones sync too). SQL: both rows
   `is_deleted` true.
6. Write the result table in `RUNS/notes.md`: action, time after T0, shown yes/no. Showing only after a
   relaunch or the hour is a followup the lead takes to Lee as a product question (what an athlete with a
   phone and a tablet should expect), filed as an `idea` Finding citing 08-024. Never showing, even after
   relaunch, is a bug Finding.

## What counts as a Finding

- Part A: anything of user 1 that user 2 sees or inherits (bug); server rows left by delete (bug); the full
  leftover list (one idea Finding). A failed delete is a hard stop (`STOPPED.md`).
- Part B: as step 6 says. A meal that shows on B with different numbers than A is a bug.
- Console errors on either simulator (or "known noise: <why>"; on the test account TrainingPeaks and V.O2
  token Degradeds are known, Sentry ticket 22). Look-around paths as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 33 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-33-index.md"` exits clean.
- [ ] `RUNS/notes.md` says `PASS 08-024` / `PASS 01-012` or names the new Finding, so the lead can close or keep each old Finding.
- [ ] Both accounts this run made are deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id. Both manual meals on the test account are deleted.
- [ ] Background processes stopped by PID (both log streams), app terminated on both simulators, `LOCK release slot testing-wave-33`, `SIM release testing-wave-33a` and `testing-wave-33b`. The simulators are left for the wave lead to drop.
- [ ] Both consoles redacted (runbook § 9.4); only `console-a-redacted.log` and `console-b-redacted.log` are kept. Prefs reads saved as key names and yes/no only.
- [ ] `findings/33-*.md` and `runs/33/` committed on the ticket branch, explicit paths only.
