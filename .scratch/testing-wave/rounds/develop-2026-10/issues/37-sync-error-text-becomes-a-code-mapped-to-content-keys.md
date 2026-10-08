# 37: Sync-error text becomes a code on the row, mapped to content keys at display time

**Status:** ready (round develop-2026-10, fix wave 4)
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

- [ ] Unit (`sync_error_code_test.dart`): each exception class → its code; a legacy English string parses to `unknown`; `syncErrorText` for each code and a `{provider}` substitution.
- [ ] Seam (`sync_status_write_seam_test.dart:128, 142-146`): the stored `last_sync_error` is the code, and `keepsReauth` keeps `reauth_required` over a later `network`.
- [ ] Widget (`connected_apps_garmin_reauth_test.dart:216`, `connected_apps_reconnect_test.dart`): the card and snackbar show the content text for `reauth_required`, never the code.
- [ ] Deno `token.test.ts` green (`deno test --allow-all`).
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator (ticket 14's dead-Garmin-token check or the next retest ticket): a 409 `garmin_reauth_required` shows the reconnect text and the row holds `reauth_required`.

Next: /testing-wave develop-2026-10 (fix wave 4)
