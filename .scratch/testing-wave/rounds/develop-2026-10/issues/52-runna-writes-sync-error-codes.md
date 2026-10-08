# 52: Runna writes sync-error codes, not raw exception text

**Status:** ready (round develop-2026-10, fix wave 6)
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

- [ ] Seam test (`runna_sync_error_code_test.dart`, after `sync_status_write_seam_test.dart`): a Runna fetch that fails offline stores `network`; a 404 calendar stores `http_404` (or the new code); the stored value parses with `SyncError.tryParse` and never contains the calendar URL.
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator (next retest ticket, Connected Apps): a dead Runna URL leaves a code on the row, never a sentence.

Next: /testing-wave develop-2026-10
