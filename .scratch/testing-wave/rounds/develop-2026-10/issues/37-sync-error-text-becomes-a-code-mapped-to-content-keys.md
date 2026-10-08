# 37: Sync-error text becomes a code on the row, mapped to content keys at display time

**Status:** fixed (wave 4, f9db3e64) awaiting retest
**Labels:** fix, round:develop-2026-10, area:integrations
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 35+36's agent (shared `content_keys.dart` and `content_defaults.json`); run after it merges.
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** `plainSyncErrorMessage` (`lib/features/integrations/domain/integration_exceptions.dart:16-39`, with its own TODO at `:12-15` asking for this) and the reconnect strings are English hardcoded in Dart and written into `integrations.last_sync_error` (Drift `integrations_table.dart:64`; server `integrations.last_sync_error TEXT`), so they bypass the content system and cannot change without a release. Lee (2026-10-08, wave 2 question k): store a short code on the row, map code → content key when shown. Line numbers from code at `4e77cf43`.

1. **Codes.** In `integration_exceptions.dart` add `enum SyncErrorCode { network, rateLimited, httpStatus, reauthRequired, unknown }` with a wire string each (`network`, `rate_limited`, `http_<status>`, `reauth_required`, `unknown`) and a parser that maps any legacy English row to `unknown`. Replace `plainSyncErrorMessage(e)` with `syncErrorCode(e)` returning the wire string.
2. **Writers.** Every `updateSyncStatus(error: …)` caller writes the code: `training_peaks_sync_service.dart:356, 564, 1019` and the refresh refusal at `:1027`; `final_surge_sync_service.dart:508, 840` and the reconnect strings at `:488, 822`; `vdot_sync_service.dart:214` and `:196`; the Garmin reauth text in `connect_training_controller.dart:1129` (TODO at `:1126-1128`, triggered by `isGarminReauthRequired`, `:50-54`). `integrations_repository.dart:403-426` (`keepsReauth`) compares on the code `reauth_required`. The upload (`:706, 734`) and download (`:800`) mappings carry the same text column; no schema change.
3. **The server agrees.** `supabase/functions/_shared/garmin/token.ts:231` writes the Garmin reauth sentence into the same column; change it to `reauth_required` and update `token.test.ts:336`.
4. **Display.** Nothing under `lib/` renders `lastSyncError` today; the Connected Apps card decides from `lastSyncStatus` (`integration.dart:93`, `connected_apps_screen.dart:321-326, 623`) and already uses `settingsConnectionNeedsReconnect` / `settingsConnectionReconnectButton`. The "Sync failed: …" snackbars in `integration_sync_helpers.dart:80, 169, 369, 434` show `result.error` / `state.errorMessage`, hardcoded. Add one helper `syncErrorText(content, code, providerName)` mapping to new keys `integrations.sync_error_network`, `_rate_limited`, `_http` (`{status}`), `_reauth` (`{provider}`), `_unknown` (`content_keys.dart`, defaults in `content_defaults.json`; the current English becomes the defaults), and use it in the four snackbars and wherever the card shows an error line.

**Findings:** none (wave 2 question k).

**Decisions:**
- Same text column, new contents: a code. Legacy rows read as `unknown`, which shows the generic text; no migration.
- The TrainingPeaks, Final Surge, V.O2 and Garmin reconnect cases collapse to one code, `reauth_required`; the provider name comes from the row, not the text.

**Touches:** lib/features/integrations/domain/integration_exceptions.dart, lib/features/integrations/application/training_peaks_sync_service.dart, lib/features/integrations/application/final_surge_sync_service.dart, lib/features/integrations/application/vdot_sync_service.dart, lib/features/integrations/presentation/providers/connect_training_controller.dart, lib/features/integrations/data/integrations_repository.dart, lib/features/integrations/presentation/integration_sync_helpers.dart, lib/features/settings/presentation/screens/connected_apps_screen.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json, supabase/functions/_shared/garmin/token.ts, supabase/functions/_shared/garmin/token.test.ts, test/features/integrations/sync_status_write_seam_test.dart, test/features/settings/connected_apps_garmin_reauth_test.dart, test/features/settings/connected_apps_reconnect_test.dart, test/features/integrations/sync_error_code_test.dart (new). 16 files. No generated files unless a `@riverpod` signature changes.

**Overlaps:** 35+36 (`content_keys.dart`, `content_defaults.json`): sequential, after their merge. 39 touches none of these files.

Deploy (dev, by the lead, from the merged tree): every function that imports `_shared/garmin/token.ts` (`grep -rl "garmin/token" supabase/functions`): garmin-backfill, garmin-push, garmin-user-mapping, garmin-ping, garmin-deregistration at least; read the import list before deploying.

- [x] Unit (`sync_error_code_test.dart`): each exception class → its code; a legacy English string parses to `unknown`; `syncErrorText` for each code and a `{provider}` substitution.
- [x] Seam (`sync_status_write_seam_test.dart:128, 142-146`): the stored `last_sync_error` is the code, and `keepsReauth` keeps `reauth_required` over a later `network`.
- [x] Widget (`connected_apps_garmin_reauth_test.dart:216`, `connected_apps_reconnect_test.dart`): the card and snackbar show the content text for `reauth_required`, never the code.
- [x] Deno `token.test.ts` green (`deno test --allow-all`).
- [x] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator (ticket 14's dead-Garmin-token check or the next retest ticket): a 409 `garmin_reauth_required` shows the reconnect text and the row holds `reauth_required`.

**Fix notes (wave 4).**
- Codes: `SyncErrorCode` + `SyncError.parse`/`tryParse` + `syncErrorCode(e)` + `syncFailureCode(...)` + `reauthRequiredCode` in `integration_exceptions.dart`; `plainSyncErrorMessage` is gone. A `TokenRefreshException(requiresReauth: true)` maps to `reauth_required`; an API 429 to `rate_limited`.
- Writers: TP (3 + `_markNeedsReconnect`), Final Surge (2 + 2 reconnect), V.O2 (1 + reconnect), the Garmin controller mirror, and one writer the ticket did not list: `training_peaks_oauth_service.dart` `_recordRefreshFailure` (wrote `Token refresh refused. Please reconnect.` / `Token refresh failed (status: N).`), now `reauth_required` / `http_N`. Not changed: `runna_sync_service.dart` still writes `e.message` / `e.toString()` (not in this ticket; it reads as `unknown` on display). The services' failure results (`*.error(e.toString())`) now carry the code too, so no raw exception reaches a snackbar.
- `keepsReauth` keeps the reconnect when the stored status is `requires_reauth` OR the stored error is `reauth_required` (the status check stays so pre-37 English rows keep their reconnect).
- Display: `syncErrorText(content, code, providerName)` and `syncFailureText(...)` in `integration_sync_helpers.dart`. The controller's sync-failure branches now leave the code in `errorMessage` plus a new `errorProvider` field; the four helper snackbars, the five "Sync failed" snackbars in `connected_apps_screen.dart` (FS/TP/V.O2 x2/Runna onboarding and connect paths) and the card error line (keyed `connected_apps.error_line`) map it to content. Non-code messages (the upload-retry note, connect failures) still show as they are.
- Content keys `integrations.sync_error_network|_rate_limited|_http|_reauth|_unknown`. `_unknown` is new copy ("{provider} sync failed. Please try again."); it replaces the old "sync failed: <stripped exception text>".
- Server: `markGarminRequiresReauth` writes `reauth_required` (`GARMIN_REAUTH_REQUIRED_CODE`). Functions importing `_shared/garmin/token.ts` (`grep -rl "garmin/token" supabase/functions`): **garmin-backfill**, **garmin-user-mapping**, **delete-user**. Only garmin-backfill calls `markGarminRequiresReauth`, so it is the one whose behaviour changes; garmin-push, garmin-ping and garmin-deregistration do not import the file.
- Twice at once / after a refresh: no new async path. Two failing syncs at once both write a code through `updateSyncStatus`; the last write wins and both are codes, and a stored `reauth_required` survives a concurrent `network` (keepsReauth). The controller's `_syncingProviders` guard still drops a second import of the same provider. After a refresh (provider rebuild) `errorMessage`/`errorProvider` reset with the state; the row keeps its code and `needsReconnect` still comes from `last_sync_status`. A content refresh between the failure and the render only changes the text, never the code.

**Questions for Lee.**
1. The `unknown` text is new copy: "{provider} sync failed. Please try again." (it used to append the stripped exception text). Keep it, or should it say more?
2. Runna still writes the raw `e.message` / `e.toString()` into `last_sync_error` (outside this ticket's writer list; it reads as `unknown` on screen, but the raw text, address included, still reaches the server row). Fold Runna into the codes in a follow-up ticket?

Next: /testing-wave develop-2026-10 (fix wave 4)
