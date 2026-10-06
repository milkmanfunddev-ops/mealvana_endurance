# 22: TrainingPeaks writeback 400

**What to build:** MEALVANA-ENDURANCE-CY, C7: updating a planned workout returns 400. Capture the request that fails, fix the payload or the precondition, and reclassify a legitimate refusal as Degraded.

**Blocked by:** 10 Contract

**Status:** done except the sandbox run and the re-auth UI (see Owed)

- [x] The failing payload identified. Found from the prod ledger and the TP write constraints, not the integration seam: there is no TP writeback integration test and `secrets/integration_test.env` has no TP creds
- [x] Fix landed with a test (`test/features/integrations/tp_writeback_400_test.dart`, red before, green after)
- [ ] Issues resolved in Sentry (lead, after merge)

## Root cause

TrainingPeaks rejects `PUT /v2/workouts/plan/{id}` with a 400 once the workout's `WorkoutDay` is more than 7 days in the past or more than a year ahead (`docs/integration/api-exploration/training-peaks/writeback.md` § Constraints). The payload itself was fine: GET, merge Description, PUT the whole object. What was missing was a precondition check. The events carry no TP request breadcrumbs (TP calls bypass the Sentry HTTP client), and `toString()` drops the body in release builds, so the evidence came from prod data (read-only):

- **MEALVANA-ENDURANCE-CY** (2026-09-26, 1.28.0+145, `ActivityDetailController._pushToTrainingPeaks`): ledger row `bb7fd081…` has `error = api_400`, activity `68f60175…` "Base run", TP workout `3711546423`, `scheduled_date_time = 2026-09-12`. The athlete saved a plan 14 days after the workout day.
- **MEALVANA-ENDURANCE-C7** (2026-09-18, 1.27.0+113, `TpWritebackService.handleDisconnect`): the disconnect strip walks every workout ever pushed and PUTs the block out. This user's TP workouts go back to 2026-02-07, and 15 of 22 were more than 7 days old on the disconnect date. The disconnect purged the ledger, so the specific workout id is gone, but the strip is the only PUT on that path. In current code the per-workout catch is already `degraded`. The event is an `error` because the legacy reporter sent it.
- **DEV-AA / DEV-AD** (2026-10-06): `POST /oauth/token` returned 400 `{"error":"invalid_grant"}`, meaning the dev account's refresh token is dead. AA (the workout sync) and AD (the event sync) are the same failure through two callers of `TrainingPeaksSyncService._refreshToken`. Both are already Degraded. The body showed up only because the build was debug. In release the `extra` had just `statusCode`.
- **DEV-AC** (vdot): `TokenRefreshException(requiresReauth: true)`, already Degraded. `VdotSyncService` returns `requiresReauth` and the manual sync shows "Please reconnect your V.O2 account". Nothing to fix here.

## Fix

- `lib/features/integrations/application/tp_writeback_service.dart`: `isWithinTpEditWindow` (7 days past, 365 days ahead, judged from the GET's `WorkoutDay`; an unreadable day lets TP decide) is checked before every PUT, on four paths: plan push, feedback push, remove, and the disconnect strip. Outside the window the PUT is skipped. The skip leaves a `note` (D9) with `workoutId`, `workoutDay` and `op`, and the ledger row closes as `failure / outside_edit_window`. An injectable `clock` was added for tests.
- `lib/features/integrations/domain/integration_exceptions.dart`: `IntegrationApiException.reportExtra` returns `statusCode` plus `responseBody`, clipped to 1000 chars. Every TP refusal now carries the body into the Report `extra` (the `diagnostic` context in Sentry): the 403 and other branches of `handleApiException`, the disconnect per-workout catch, and the three token refresh catches in `training_peaks_oauth_service.dart` (2) and `training_peaks_sync_service.dart` (1). The next 400 will be diagnosable from the event alone.
- Any other 4xx from a TP write stays Degraded (`handleApiException`), never Fault.
- Test: `test/features/integrations/tp_writeback_400_test.dart`. It uses the real `TrainingPeaksApiClient` and the real Supabase client over a fake HTTP transport that answers like TP and PostgREST: a GET with a naive `WorkoutDay`, the documented 400 envelope, ledger insert and patch. The token test also runs through the real `TrainingPeaksOAuthService`. Cases:
  - CY replay: no PUT, a note, the ledger closes as `outside_edit_window`.
  - A 400 inside the window: Degraded, with `responseBody` in `extra`.
  - C7 replay: disconnect sends no PUT and the local log is purged.
  - Window boundaries.
  - Refresh 400 `invalid_grant`: Degraded, with the body, and the integration parked in `error`.

  To prove red-before I disabled the guard and `reportExtra` in place, because the test needs the new `clock` parameter to compile. Four tests went red: an unexpected PUT ×2, and `responseBody` null ×2.
- Verified: `dart analyze` clean on the changed files. Green: `tp_writeback_400_test.dart`, `tp_writeback_di10_test.dart`, `tp_ispremium_a1_test.dart`, `test/shared/source_guard`. I did not run the full suite.

## Owed

- **Sandbox seam run not done.** There is no TrainingPeaks writeback test in `integration_test/`, and `secrets/integration_test.env` has no TP credentials. The exact text of TP's edit-window 400 is unconfirmed: the prod events predate body capture. Behavior at exactly 7 days past is also unconfirmed. The guard treats day 7 as inside, so if TP disagrees, that one day produces a Degraded 400 with its body attached.
- **No user-facing message for an edit-window skip.** Plan and feedback pushes are fire-and-forget after the save, and the activity detail UI is frozen. A MealvanaSnackbar there would need a state channel plus a ruling on whether athletes should be told at all. The coach simply never sees the block on a workout more than a week old. This is a product call for Lee/Xuan.
- **Background re-auth prompt for a dead TP refresh token does not exist.** The refresh 400 is Degraded, not silent. `TrainingPeaksOAuthService` parks the integration in `last_sync_status = 'error'`, but nothing in `lib/` reads `lastSyncStatus`. The athlete sees "Sync failed: Token expired. Please reconnect." (MealvanaSnackbar) only on a manual Sync Now in Connected Apps. `TrainingPeaksSyncService._refreshToken` also does not write the `error` status. Fixing this needs a reconnect banner or badge on the provider card; that is a design question, not part of this ticket.
- Dev account `607f9dd5…` (role coach) has dead TP and V.O2 refresh tokens. Reconnect both in the app to silence DEV-AA, AD and AC.

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-CY | resolve | TP refuses plan writes when WorkoutDay is more than 7 days past (this workout was 14 days old). Writeback now checks the edit window before PUT and notes the skip. Any other TP 4xx is Degraded with the response body in extra. Ticket 22. |
| MEALVANA-ENDURANCE-C7 | resolve | The disconnect strip PUT to workouts months past TP's 7-day edit window. The strip now skips them (noted), and per-workout failures are Degraded with the response body. Ticket 22. |
| MEALVANA-ENDURANCE-DEV-AA | resolve-as-degraded | TP refresh token revoked (invalid_grant). Already Degraded; the response body now reaches extra in release builds too. Reconnect the dev account. Ticket 22. |
| MEALVANA-ENDURANCE-DEV-AD | resolve-as-degraded | Same invalid_grant as DEV-AA, through the event-sync caller. Already Degraded, body now in extra. Ticket 22. |
| MEALVANA-ENDURANCE-DEV-AC | resolve-as-degraded | V.O2 refresh token expired. Degraded, and the reconnect message reaches the user on sync. No code change. Ticket 22. |
