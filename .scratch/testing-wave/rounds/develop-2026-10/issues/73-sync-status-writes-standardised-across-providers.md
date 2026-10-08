# 73: Sync-status writes are standardised across the five providers

**Status:** ready (round develop-2026-10, fix wave 8)
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

- [ ] Seam, one case per provider through the real sync service on `FakePostgrest`: offline → row reads `error` / `network`; a 401 refresh → `requires_reauth` / `reauth_required`; a 404 → `http_404`; Runna non-ICS body → `not_a_calendar`; an inactive row → no write (64). A following success clears both columns.
- [ ] Content: the new key resolves with its default; `integration_sync_helpers.dart` maps every `SyncErrorCode` (the switch stays exhaustive).
- [ ] #116 (`updateSyncStatus`, `syncErrorCode`, every sync service class), #117, `flutter analyze` clean.
- [ ] Retest on a simulator (Connected Apps): a dead Runna link shows the not-a-calendar line; offline Sync Now on V.O2 leaves `network` on the row and the generic offline line on the card; reconnect clears it.

Next: /testing-wave develop-2026-10
