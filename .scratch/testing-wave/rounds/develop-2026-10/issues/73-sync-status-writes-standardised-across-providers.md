# 73: Sync-status writes are standardised across the five providers

**Status:** landed (wave 8, 2026-10-09, develop-next `4b146f27`); open until its retest passes in test wave 9 (retest tickets 85-87)
**Labels:** fix, round:develop-2026-10, area:integrations
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing in code; cut at the wave-6 close from ticket 52's Q1+Q2.
**Next:** `/testing-wave develop-2026-10` (fix wave after test wave 7)
**Model:** opus

**What to build:** Lee, 2026-10-08: "Is it not possible to have all the different integration methods be standardized?" Yes: one shared step every provider's sync failure goes through, so the same failure writes the same code on the integration row and Connected Apps shows the same line. Today (at `8dec4583`): TrainingPeaks writes `network` when offline; Runna, Final Surge and V.O2 leave the row alone on a transient; Garmin mirrors server status through `connect_training_controller.dart`; Runna stores `unknown` for a link that is not a calendar.

1. **One step.** A shared `recordSyncFailure(provider, error)` (in `lib/features/integrations/application/`, beside `integration_sync_coordinator.dart`) that maps the error with `syncErrorCode(e)` and calls `IntegrationsRepository.updateSyncStatus` with status `error` (or `requires_reauth` for `reauth_required`) and the code. Every provider's sync service catch (`training_peaks_sync_service.dart`, `final_surge_sync_service.dart`, `vdot_sync_service.dart`, `runna_sync_service.dart`) and the controller's Garmin mirror call it; no provider keeps its own rule. Ticket 64's guard (no write on an inactive or missing row) stays inside `updateSyncStatus`.
2. **The same codes for the same failures.** Offline / timeout / handshake / reset → `network` (every provider, including the three that write nothing today); refused token → `reauth_required`; HTTP → `http_<status>`; a Runna link that answers but is not an ICS calendar, or is not a URL → new `not_a_calendar` (`SyncErrorCode`, content key `integrations.sync_error_not_a_calendar`, default "This link isn't a Runna calendar. Copy a fresh link from Runna and connect again.", mapped in `integration_sync_helpers.dart`'s exhaustive switch).
3. **Success clears.** A later successful sync writes `success` and null error on every provider (check each; TrainingPeaks and Final Surge do, confirm V.O2 and Runna).
4. `_trackIntegrationSyncFailed` sends the code on every provider (52 item 2 left the controller's own catch on `e.toString()`; fix it here).

**Findings:** none (52 Q1, Q2).

**Decisions:** Lee, 2026-10-08: standardise, one ticket, replaces 52's two questions.

**Touches:** lib/features/integrations/application/sync_failure_recorder.dart (new), the four sync services above, lib/features/integrations/presentation/providers/connect_training_controller.dart (Garmin mirror + `_trackIntegrationSyncFailed`), lib/features/integrations/domain/integration_exceptions.dart, lib/features/integrations/presentation/integration_sync_helpers.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json, test/features/integrations/sync_failure_recorder_seam_test.dart (new, one case per provider), test/features/integrations/sync_error_code_test.dart, test/features/integrations/runna_sync_error_code_test.dart, test/features/integrations/sync_status_write_seam_test.dart. About 13 files. `ConnectTrainingController` is `@riverpod`: unfiltered codegen if a signature changes.

**Overlaps:** 71 and 72 share no file. Never alongside any other ticket editing `connect_training_controller.dart`.

No edge-function or schema change. Nothing to deploy.

- [x] Seam, one case per provider through the real sync service on `FakePostgrest`: offline → row reads `error` / `network`; a 401 refresh → `requires_reauth` / `reauth_required`; a 404 → `http_404`; Runna non-ICS body → `not_a_calendar`; an inactive row → no write (64). A following success clears both columns.
- [x] Content: the new key resolves with its default; `integration_sync_helpers.dart` maps every `SyncErrorCode` (the switch stays exhaustive).
- [x] #116 (`updateSyncStatus`, `syncErrorCode`, every sync service class), #117, `flutter analyze` clean.
- [ ] Retest on a simulator (Connected Apps): a dead Runna link shows the not-a-calendar line; offline Sync Now on V.O2 leaves `network` on the row and the generic offline line on the card; reconnect clears it.

## Fix notes

Wave 8, 2026-10-09, commit `db30bd058` on `testing-wave/develop-2026-10/73`.

**What changed.**
- New `lib/features/integrations/application/sync_failure_recorder.dart`: an extension on `IntegrationsRepository` with `recordSyncFailure(userId, provider, error)` (maps the error with `syncErrorCode`, writes `requires_reauth` for `reauth_required` and `error` for every other code, returns the code) and `recordReauthRequired(userId, provider)` (for callers that know the token was refused without an exception in hand; it goes through `recordSyncFailure`). This is the single entry point 77 and 84 can call.
- Every sync-status failure write now goes through it: TrainingPeaks (`syncWorkouts`, `syncWorkoutsByDateRange`, `_recordRefreshFailed`, `_markNeedsReconnect`), `TrainingPeaksOAuthService._recordRefreshFailure`, Final Surge (both sync methods), V.O2, Runna, and the controller's Garmin mirror (`_markGarminNeedsReauth`). No provider keeps its own status rule.
- Offline (`NetworkException`) now writes `error` / `network` on Final Surge, V.O2 and Runna, which wrote nothing before. A Final Surge or V.O2 refresh that failed without a refusal (5xx, offline) now writes its code; before, it wrote nothing.
- New `SyncErrorCode.notACalendar` (`not_a_calendar`) and `NotACalendarException` in `integration_exceptions.dart`; `RunnaIcsClient` throws it for a link that is not an http(s) URL and for a 200 body without `BEGIN:VCALENDAR`. `syncErrorText` maps it to `ContentKeys.integrationsSyncErrorNotACalendar` (the switch stays exhaustive). `NotACalendarException` keeps the parent's `toString`, so the Runna connect error line reads as before.
- `_trackIntegrationSyncFailed` now takes a required `errorCode` and every call site passes a wire code: `reauth_required` for the token branches, `network`, `syncFailureCode(error: ...)` for result errors, and `syncErrorCode(e)` in the controller's own catches (was `e.toString()`).
- Ticket 64's guard is unchanged inside `updateSyncStatus`; its skip is still noted to Sentry (`Sync status not written: integration inactive or missing`), so D9 holds for the new write paths. No new early return or swallowed error was added.
- Outside the Touches list: `lib/features/integrations/data/runna_ics_client.dart` (throws the new exception) and `lib/features/integrations/application/training_peaks_oauth_service.dart` (its refresh-failure write goes through the shared step). Neither is on the wave's do-not-touch list.

**#77, concurrency.**
- Two providers failing at once: each call writes only its own `(user, provider)` row, so they do not interfere. The seam test runs V.O2 offline and Runna not-a-calendar together; each row keeps its own code.
- A sync that fails during or after a disconnect: the service reaches `recordSyncFailure` after the row went inactive, `updateSyncStatus` finds it inactive, writes nothing, and notes the skip. One seam case per provider deactivates the row while the request is in flight.
- The same provider failing twice at once (a Sync Now beside a coordinator sync): both writes land the same status and code, last write wins, and the result is the same either way. A `requires_reauth` row stays `requires_reauth` when an `error` write follows (ticket 138's keep rule in `updateSyncStatus`).
- After a refresh (provider invalidated mid-sync): the recorder holds no state; it reads the row inside `updateSyncStatus` at write time.

**Item 3, success clears both columns.** Confirmed per provider in the seam test: after each failure, a successful sync leaves `last_sync_status = success` and `last_sync_error = null` locally and on the server upsert. TrainingPeaks, Final Surge, V.O2 and Runna each call `updateSyncStatus(status: 'success')` with no error, and `updateSyncStatus` writes `Value(error)`, which is null. Garmin's row is written by the server; the client only mirrors `requires_reauth`.

**Tests run** (each file on its own; no full suite):
- test/features/integrations/sync_failure_recorder_seam_test.dart (new): 20 pass. Per provider: offline, 404, refused refresh (not Runna), not-a-calendar and not-a-URL (Runna), disconnected mid-sync, each failure followed by a clearing success; Garmin mirror and its inactive-row skip; two providers at once. A mutation check (recorder storing `unknown` for `network`) turned 5 cases red.
- sync_error_code_test.dart: 26 pass (new code, new key text, every `SyncErrorCode` has its own text)
- runna_sync_error_code_test.dart: 4 pass (not-a-calendar and offline expectations updated)
- runna_sync_service_test.dart: 12 pass (offline now expects the `network` write)
- sync_now_analytics_test.dart: 9 pass (new: a throwing sync on each provider sends `error_message: network` through the real notifier)
- sync_status_write_seam_test.dart 12, tp_refresh_requires_reconnect_seam_test.dart 19, final_surge_sync_service_test.dart 15, final_surge_completion_sync_seam_test.dart 6, final_surge_lookback_test.dart 3, integration_sync_coordinator_test.dart 11, integrations_rls_seam_test.dart 3, reconnect_unhides_seam_test.dart 9, reconnect_clears_sync_state_test.dart 6, disconnect_clears_reconnect_seam_test.dart 1, runna_ics_client_test.dart 9, tp_ispremium_a1_test.dart 7, tp_writeback_400_test.dart 11, tp_writeback_di10_test.dart 9, connect_cancel_is_quiet_seam_test.dart 2, connect_identity_seam_test.dart 3, garmin_backfill_failure_report_test.dart 4, test/features/onboarding/connect_training_failure_test.dart 3, onboarding_overflow_test.dart 8, test/features/settings/connected_apps_garmin_reauth_test.dart 3, connected_apps_reconnect_test.dart 6, test/smoke_tests/settings_smoke_test.dart 13, test/shared/source_guard/ 20. All pass.
- `flutter analyze` on the 15 touched files: no errors or warnings (2 pre-existing infos).
- No codegen: no annotated signature changed.

**Questions for Lee.**
1. A 401 that comes back on a data call after a fresh token is handled two ways. TrainingPeaks marks the connection `requires_reauth` (ticket 76), while Final Surge and V.O2 store `http_401` as an ordinary error, so the card says "sync failed (status 401)" and offers no Reconnect. Should Final Surge and V.O2 follow TrainingPeaks? That is a one-line change in `syncErrorCode` (`TokenExpiredException` → `reauth_required`). I left it as it is because it changes when Connected Apps offers Reconnect.

Next: /testing-wave develop-2026-10
