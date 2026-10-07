# 14: A dead Garmin token, and the TrainingPeaks write-back edit window

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:integrations, sentry-device-check
**Branch:** `develop-next`
**Source:** new; the device checks Sentry tickets 19 and 22 left owed
(`.scratch/sentry/issues/19-edge-gateway-502-and-504.md`, `22-trainingpeaks-writeback-400.md`)
**Blocked by:** 13 (same provider logins; a Garmin user maps to one account at a time).
**Next:** `/testing-wave develop-2026-10 --only 14`
**Model:** opus

**What to test:** Two behaviours the Sentry work changed and nobody has seen on a device.
(A) When Garmin says the athlete's token is dead, `garmin-backfill` answers 409
`garmin_reauth_required` and the app records a Degraded, not a Fault. (B) TrainingPeaks write-back
skips a workout more than 7 days in the past (TP refuses those with a 400), notes the skip, and still
writes workouts inside the window.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/14/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** one new `lee+e2e-14-<UTC time>@rightpathprogramming.com`. Garmin and TrainingPeaks test
logins from `CRED list` (test athletes only, never Lee's own). Missing login: a followup-test Finding
for that half and go on with the other. `secrets/integration_test.env`: never opened or printed.

**App data:** cleared by the wave lead.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Welcome, onboarding, signup | as ticket 01 | `lib/features/onboarding/`, `lib/features/auth/presentation/screens/` |
| Connected Apps: Garmin Connect card (Connect, Sync Now, Disconnect), TrainingPeaks card (Connect, write-back switch, Disconnect) | Settings → Connected Apps → `/settings/connected-apps` | `lib/features/settings/presentation/screens/connected_apps_screen.dart`, `lib/features/settings/presentation/widgets/tp_writeback_toggle_row.dart` |
| Garmin and TrainingPeaks sign-in sheets (out of process) | Connect | runbook § 5 |
| Garmin Connect web, connected apps page; TrainingPeaks web, workout view | Chrome (claude-in-chrome) | provider sites |
| Timeline workout cards | `/main` | `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart` |
| Activity detail (fuel plan save) for a past and a future TP workout | tap a workout card → `/plan?activityId=…` | `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` |
| Settings → Account → Delete Account | `/settings` | `settings_screen.dart` |

## Expected records (`RUNS/expected.md`)

Columns from `information_schema` first; never a token column.
- Part A: `integrations` garmin row active after connect; `garmin_user_mappings` row (user id, Garmin
  user id, created_at). After the revoke and Sync Now: a `garmin-backfill` edge log line answering 409
  `garmin_reauth_required`; in Sentry `mealvana-endurance-dev`, one `warning` event with message
  "garmin-backfill 409: Garmin token expired, athlete must reconnect Garmin" (area `garmin`) and no
  `error` event for `garmin-backfill` in the window. After disconnect: the garmin row inactive or gone
  (per the disconnect code) and the mapping removed.
- Part B: `integrations` trainingpeaks row active; `tp_writeback_ledger` (id, activity_id,
  tp_workout_id, block_kind, status, error, pushed_at): past workout → `failure` / `outside_edit_window`,
  no PUT; future workout → the success status the code writes, and the block visible on TrainingPeaks.
  After disconnect: the future workout's block stripped (ledger row for the remove op), the past one
  skipped with a Note; no TrainingPeaks 400 event in Sentry.
- After account delete: no `integrations`, `garmin_user_mappings` or `tp_writeback_ledger` rows for
  the user. RevenueCat: none expected (no purchase in this ticket).

## Part A: Garmin dead token → 409 → Degraded

From code (unverified): `ConnectTrainingController.triggerGarminBackfill`
(`lib/features/integrations/presentation/providers/connect_training_controller.dart`) calls
`garmin-backfill`. On a 409 with `garmin_reauth_required` (`isGarminReauthRequired`) it reports
`report.degraded(area: garmin, 'garmin-backfill 409: Garmin token expired, athlete must reconnect
Garmin')` and does not schedule the 30-minute retry. The function's per-cause answers are in
`supabase/functions/garmin-backfill/outcome.ts`: any Garmin 401 → 409, all 429 → 429 with
`Retry-After`, else 502. Garmin's card "Sync Now" calls the backfill every tap (`syncGarmin` in
`lib/features/integrations/presentation/integration_sync_helpers.dart`); opening Connected Apps also
fires it once per session behind a 6-hour cooldown.

1. Sign up. Connect Garmin with the test login. Sync Now once: a healthy 202 path. Record it.
2. Kill the token the way an athlete would: in Chrome (claude-in-chrome), sign in to Garmin Connect
   with the same login and remove Mealvana from its connected apps. Write the time.
3. Back in the app: Connected Apps → Garmin → Sync Now. Repeat every few minutes until the function
   answers 409 or 20 minutes pass (write "not seen live" and how you checked instead).
4. Evidence: the `garmin-backfill` edge log line with the 409 and the Garmin statuses
   (`scripts/edge_logs.sh`, `-s function_edge_logs` for the request line); the console's Degraded line;
   the dev Sentry project (org `milkman-24`, project `mealvana-endurance-dev`, token from
   `~/.sentryclirc`, never printed) shows a warning-level event with that message and no error-level
   event for `garmin-backfill` in the window.
5. The snackbar still says Garmin data is "temporarily delayed" and will retry. Sentry ticket 19 left
   this as a product question (the athlete should be told to reconnect). File it as a bug Finding that
   cites the ticket; do not treat it as new.
6. Disconnect Garmin.

## Part B: TrainingPeaks write-back edit window

From code (unverified): `TpWritebackService.isWithinTpEditWindow`
(`lib/features/integrations/application/tp_writeback_service.dart`) allows 7 days past to 365 days ahead,
judged from the GET's `WorkoutDay`; outside it the PUT is skipped, a Note is recorded with workoutId,
workoutDay and op, and the `tp_writeback_ledger` row closes `failure` / `outside_edit_window`. Any
other TP 4xx is Degraded with `responseBody` in the report's extra. Disconnect strips the block from
every pushed workout, skipping the old ones the same way.

1. Connect TrainingPeaks with the test login. Turn write-back on (consent sheet).
2. Pick two imported planned workouts: one 8 to 30 days in the past, one today or later. If the test
   athlete has none in the past window, write a followup-test Finding ("needs a TP test athlete with a
   planned workout 8–30 days back") and do only the future one.
3. Past workout: open its detail, create or save its fuel plan. Expect no PUT (console), a Note, and
   SQL on `tp_writeback_ledger` (id, activity_id, tp_workout_id, block_kind, status, error, pushed_at):
   `failure`, `outside_edit_window`. No Degraded or Fault for a 400.
4. Future workout: same save. Ledger `success` (or whatever success value the code writes). In Chrome,
   open the workout on TrainingPeaks and read the fuel block in its description.
5. Disconnect TrainingPeaks. Ledger and console: the future workout's block is stripped, the past one
   skipped with a Note. Sentry: no TP 400 event in the window.
6. Delete the account in the app.

Standing rule: Activity detail keeps its look and copy; only wrong numbers and broken navigation are
bugs there. Sentry ticket 22 left "no message to the athlete for a skipped write" as a product
question: note it, do not file it as new.

## What counts as a Finding

- Part A: a Fault for a dead token, a 502 where the function should answer 409, a 30-minute retry
  scheduled after a 409.
- Part B: a PUT outside the window, a 400 reaching Sentry, a ledger row that disagrees with what
  happened, a future write that never lands on TrainingPeaks.
- Console errors; look-around paths as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 14 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-14-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-14`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/14-*.md` and `runs/14/` committed on the ticket branch, explicit paths only.
