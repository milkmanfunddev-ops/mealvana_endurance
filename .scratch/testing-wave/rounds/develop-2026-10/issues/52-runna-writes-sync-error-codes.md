# 52: Runna writes sync-error codes, not raw exception text

**Status:** landed (wave 6, 2026-10-08, develop-next `8dec4583`); open until its retest passes in test wave 7 (tickets 67-69; 61/62/64 server-side checks at the wave-7 close)
**Labels:** fix, round:develop-2026-10, area:integrations
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing in code; runs in the fix wave after retest wave 5 (cut at the wave-4 close from ticket 37's question 2).
**Next:** `/testing-wave develop-2026-10` (fix wave after retest wave 5)
**Model:** opus

**What to build:** Ticket 37 (`f9db3e64`, landed `98b15919`) made every `updateSyncStatus(error: …)` writer store a wire code (`SyncErrorCode`: `network`, `rate_limited`, `http_<status>`, `reauth_required`, `unknown`) and map it to content at display time. Runna was left out: `runna_sync_service.dart` still writes `e.message` / `e.toString()` into `integrations.last_sync_error`, so raw exception text (a URL with the calendar token, an address) reaches the server row. On screen it already reads as the generic `unknown` line. Lee, 2026-10-08: move Runna onto the codes.

Sites, from code at `98b15919` (re-read before editing):
```
223:      await _integrationsRepository.updateSyncStatus(
268:      await _integrationsRepository.updateSyncStatus(
276:      await _integrationsRepository.updateSyncStatus(
```

1. Each `error:` argument becomes `syncErrorCode(e)` (`lib/features/integrations/domain/integration_exceptions.dart`). A Runna-specific failure that none of the codes fits (a calendar URL that answers 404, a feed that is not ICS) gets its own code added to `SyncErrorCode` with a content key `integrations.sync_error_<code>` and a default, following 37's pattern; do not widen `unknown` to carry text.
2. `_trackIntegrationSyncFailed` for Runna sends the code, as 37 left it for the other providers.
3. Nothing else: the Runna row deletion on disconnect (`connect_training_controller.dart`, ticket 47 item 1 notes it) is unchanged.

**Findings:** none (ticket 37's question 2; the raw-text-to-server concern is #112's rule).

**Decisions:** Lee, 2026-10-08: yes, follow-up ticket.

**Touches:** lib/features/integrations/application/runna_sync_service.dart, lib/features/integrations/domain/integration_exceptions.dart (only if a new code is needed), lib/features/content/domain/content_keys.dart and assets/config/content_defaults.json (only with a new code), test/features/integrations/runna_sync_error_code_test.dart (new), test/features/integrations/sync_error_code_test.dart (if a code is added). 2 to 6 files. No generated files.

**Overlaps:** 53 and 54 share nothing with it.

No edge-function or schema change. Nothing to deploy.

- [x] Seam test (`runna_sync_error_code_test.dart`, after `sync_status_write_seam_test.dart`): a Runna fetch that fails offline stores `network`; a 404 calendar stores `http_404` (or the new code); the stored value parses with `SyncError.tryParse` and never contains the calendar URL.
- [x] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator (next retest ticket, Connected Apps): a dead Runna URL leaves a code on the row, never a sentence.

## Fix notes

Fix wave 6 pass A, branch `testing-wave/develop-2026-10/52-53`.

- `lib/features/integrations/application/runna_sync_service.dart`: the three failure branches now go through `syncErrorCode(e)`. The `IntegrationApiException` and generic `catch` branches write the code to `updateSyncStatus(error: …)` and return it in `RunnaSyncResult.error`. The `NetworkException` branch returns `RunnaSyncResult.networkError('network')` instead of `e.message`, which could carry the feed URL through a `ClientException`.
- Item 2: `_trackIntegrationSyncFailed('runna', …)` in `connect_training_controller.dart` sends `result.error`, so it now sends the code with no controller edit. The controller's own `catch` still tracks `e.toString()`, the same as 37 left it for the other providers. The presentation folder was off-limits this pass.
- No new `SyncErrorCode`. A 404 is `http_404`. A feed that is not ICS, or a link that is not a URL, is an `IntegrationApiException` with no status, so it stores `unknown`. A dedicated code would need a new arm in the exhaustive `switch` in `presentation/integration_sync_helpers.dart` (off-limits this pass) and a way to tell the two cases apart in `data/runna_ics_client.dart` (also off-limits). See question 2.
- Offline does not stamp the row. A `NetworkException` stays transient, as it does for Final Surge and V.O2 (TrainingPeaks does stamp `network`, see `sync_status_write_seam_test.dart`): the row keeps its status and the result carries `network`. Only a socket failure that escapes the client reaches the generic `catch` and stores `network`. The seam test pins both. See question 1.
- Tests: `test/features/integrations/runna_sync_error_code_test.dart` (new, 4 tests: 404 → `http_404`; HTML body → `unknown`; `ClientException` offline → result `network`, row untouched; escaped `SocketException` → `network` on row and wire; every stored value parses with `SyncError.tryParse` and never contains the feed URL or token). `runna_sync_service_test.dart`: the 404 expectation changes from the message to `http_404`.
- Runs: `runna_sync_error_code_test.dart` + `runna_sync_service_test.dart` 16/16 pass. #116 grep (`RunnaSyncService`, `syncErrorCode`, `SyncErrorCode`): `sync_error_code_test.dart`, `integration_sync_coordinator_test.dart`, `sync_status_write_seam_test.dart` 40/40 pass. `flutter analyze` on the three touched files: no issues. No catch added, so the source guard was not run.
- Left for the lead: the retest box (simulator).

**Questions for Lee.**

1. The exit box says "a Runna fetch that fails offline stores `network`". Today a plain offline sync stores nothing on the row, the same as Final Surge and V.O2 (TrainingPeaks stamps `network`): it is treated as transient and the athlete just retries. Should an offline Runna sync stamp `error` + `network` on the row? Recommended: no, keep it with Final Surge and V.O2.
2. Should "this link didn't return a calendar" get its own code (for example `not_a_calendar`) instead of the generic `unknown` line? It needs the Runna client and the display helper touched, so it would be a small follow-up ticket. Recommended: yes, as a follow-up, because the fix for the athlete (copy a fresh link from Runna) is different from "try again".

Next: /testing-wave develop-2026-10
