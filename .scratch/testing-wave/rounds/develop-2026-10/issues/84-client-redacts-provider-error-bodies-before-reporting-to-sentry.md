# 84: The app reports a provider's status and error code, never its error body

**Status:** landed (wave 8, 2026-10-09, develop-next `4b146f27`); open until its retest passes in test wave 9 (retest tickets 85-87)
**Labels:** fix, round:develop-2026-10, area:integrations, area:privacy
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Finding 69-012 (the device-side twin of ticket 76); TRIAGE.md rulings of 2026-10-09 (Lee: "a separate client fix ticket, fix wave 8, after 73")
**Blocked by:** 73, after 73 merges. Both edit `lib/features/integrations/domain/integration_exceptions.dart` (73 adds `SyncErrorCode.notACalendar` there; 84 changes `IntegrationApiException`, `:147-191`). Re-read line numbers after the merge. No file shared with 74, 75, 76 or 77.
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

Line numbers are from code at `84615131`.

## Findings

- **69-012 (device side), found while drafting 76.** On the server, garmin-backfill printed Garmin's `invalid_grant` body, whose `error_description` carried the refresh token (`runs/69/edge-23-16-to-23-44.txt`). The app reports provider error bodies to Sentry the same way. From code; no run has caught a token in a dev Sentry event yet:
  - **TrainingPeaks, every build.** `IntegrationApiException.reportExtra` (`lib/features/integrations/domain/integration_exceptions.dart:161-176`) puts up to 1,000 characters of the body into a Report's `extra` as `responseBody`. It is read on the token-refresh failures:
    - `training_peaks_oauth_service.dart:254-260` (`refreshTokenIfNeeded`) and `:299-305` (`forceRefreshToken`);
    - `training_peaks_sync_service.dart:990-999` (`_refreshToken`);
    - the write-back sites `tp_writeback_service.dart:699, :769, :787`.
    The bodies come from `training_peaks_api_client.dart:139-145` (refresh) and `:93-98` (code exchange).
  - **Debug builds (every testing-wave build), all four providers.** `IntegrationApiException.toString()` appends the whole body when `kDebugMode` (`integration_exceptions.dart:185`). A connect failure is reported with `fault(error)` (`connect_training_controller.dart:705`, `integrationFailure` `:2538-2551`), so the exception text, body included, reaches dev Sentry. Bodies reach `toString()` from:
    - Final Surge's code exchange (`final_surge_api_client.dart:88-93`, `:105-112`);
    - TrainingPeaks' code exchange (`training_peaks_api_client.dart:93-98`);
    - `HttpRetryClient`'s 403/5xx/default errors (`mapStatusToException`, `http_retry_client.dart:170-221`).
  - **Final Surge, every build.** A 200 with an `error` field becomes `'Token exchange failed: $errorMessage'` with the raw `error` text (`final_surge_api_client.dart:100-112`).
  - **Garmin, every build.** The code exchange throws `GarminOAuthException('Token exchange failed: ${response.statusCode} ${response.body}')` (`lib/features/integrations/application/garmin_oauth_service.dart:270-273`). The message reaches Sentry through `fault` (`connect_training_controller.dart:705`), the on-screen error (`errorMessage: e.toString()`, `:707-713`) and Mixpanel (`_trackIntegrationConnectFailed(errorMessage: e.toString())`, `:715-719`).
  - **V.O2, every build.** `_extractErrorReason` (`lib/features/integrations/data/vdot_api_client.dart:53-75`) folds `error_description` first, or else up to 200 characters of raw text, into the exchange's message (`:134-150`). That is the same field that carried Garmin's token.
  - Not affected (from code): Final Surge's and V.O2's refreshes throw `TokenRefreshException` with a fixed message and no body (`final_surge_api_client.dart:144-157`, `http_retry_client.dart:230-251`). Runna has no OAuth.

## Fix

**Ruling (2026-10-09):** one shared redaction: status and error code only, never the description or the body. Apply it before any Report/Sentry call and in every exception message. This is the same rule as ticket 76's server helper (`supabase/functions/_shared/provider_error.ts`).

1. **One helper.** New `lib/features/integrations/domain/provider_error_summary.dart`:
   - a pure `({int? status, String? errorCode}) providerErrorSummary(int? status, String? body)`;
   - parse `body` as JSON, take the first of `error`, `errorCode` or `code` that is a string matching `^[A-Za-z0-9_.-]{1,64}$`; anything else gives `null`;
   - never return `error_description`, `message`, `errorMessage`, the raw body or a slice of it. V.O2's `{"status":"NOK","error":"invalid_code"}` gives `invalid_code`;
   - the doc comment names the ruling, 69-012 and ticket 76.
2. **`IntegrationApiException`** (`integration_exceptions.dart:147-191`, after 73 merges):
   - `reportExtra` returns `{'statusCode': statusCode, 'errorCode': summary.errorCode}`;
   - `maxReportedBodyChars` and `responseBody` go;
   - `toString()` writes `(status: N, error: <code>)` and never the body, in any build.
   The `body` field stays for in-memory checks. No caller reads it (from code: `grep -rn "\.body\b" lib/features/integrations` finds only constructors). Every `reportExtra` caller above is covered with no change at the call site.
3. **Garmin** (`garmin_oauth_service.dart:270-273`). Build the exception through a `@visibleForTesting static GarminOAuthException tokenExchangeFailure(http.Response r)`: `'Token exchange failed: ${s.status}${s.errorCode != null ? ' ${s.errorCode}' : ''}'`. That gives the seam test a way in without the web-auth sheet. `_fetchGarminUserId` (`:297-300`) already carries the status only.
4. **V.O2** (`vdot_api_client.dart:53-75`). `_extractErrorReason` returns `summary.errorCode ?? 'HTTP <status>'`; drop the raw-text fallback and `error_description`. The `invalid_payload` hint (`:140-145`) keeps working on the code.
5. **Final Surge** (`final_surge_api_client.dart:100-112`). The message uses `providerErrorSummary(response.statusCode, response.body).errorCode`, so a non-code `error` text becomes `'Token exchange failed'` with no detail. The debug `print`s of the whole body (`:80-83`, `:86-88`) go: they reach the wave's console logs.
6. **TrainingPeaks.** Nothing beyond item 2.

The on-screen connect error and the Mixpanel `errorMessage` carry `e.toString()` (`connect_training_controller.dart:707-719`). With items 2-5 the exceptions hold no body, so the controller does not change.

## Touches

lib/features/integrations/domain/provider_error_summary.dart (new)
lib/features/integrations/domain/integration_exceptions.dart (shared with 73: after 73 merges)
lib/features/integrations/application/garmin_oauth_service.dart
lib/features/integrations/data/vdot_api_client.dart
lib/features/integrations/data/final_surge_api_client.dart
test/features/integrations/provider_error_redaction_seam_test.dart (new)
test/features/integrations/provider_error_summary_test.dart (new)
test/features/integrations/tp_writeback_400_test.dart

8 files. No annotated file changes, so no codegen. `training_peaks_oauth_service.dart`, `training_peaks_sync_service.dart`, `tp_writeback_service.dart`, `training_peaks_api_client.dart`, `http_retry_client.dart` and `connect_training_controller.dart` are covered through item 2 and do not change.

## Tests

- [x] **Seam, one case per provider path** (`provider_error_redaction_seam_test.dart`). Each stub answers with Garmin's real shape, the body carrying a token: `{"error":"invalid_grant","error_description":"Invalid refresh token: <base64 of {"refreshTokenValue":"rt-live-5f2c"}>"}`. Run the real client or service with `package:http/testing.dart`'s `MockClient` and a Report fake. Tests run with `kDebugMode` true, so they also prove the debug `toString()` path. Each case asserts the Report's message, `extra` and error text, and the exception's `toString()`. None contains `rt-live-5f2c`, the base64 string or a 12-character slice of it, `Invalid refresh token`, or `error_description`. Each contains the status and `invalid_grant`.
  - **TrainingPeaks refresh:** `TrainingPeaksOAuthService.refreshTokenIfNeeded` on an expired row, the token endpoint answering 400 → one `degraded`, `extra == {statusCode: 400, errorCode: 'invalid_grant'}`. The same through `forceRefreshToken`, and through `TrainingPeaksSyncService._refreshToken` (via a sync) on the harness of `tp_refresh_requires_reconnect_seam_test.dart`.
  - **TrainingPeaks code exchange:** `exchangeCodeForToken` answering 400 → the thrown exception's `toString()`.
  - **Final Surge code exchange:** `FinalSurgeApiClient.exchangeCodeForToken` answering 400 with the body, and answering 200 with `{"error":"Invalid refresh token: rt-live-5f2c"}` → message `Token exchange failed`, no token.
  - **Garmin code exchange:** `GarminOAuthService.tokenExchangeFailure(http.Response(body, 400))` → message `Token exchange failed: 400 invalid_grant`. Then through the connect path's `integrationFailure` with a Report fake: the fault's error text has no token.
  - **V.O2 code exchange:** `VdotApiClient.exchangeCodeForToken` answering 400 `{"status":"NOK","error":"invalid_code","error_description":"code rt-live-5f2c is invalid"}` → `Token exchange failed: invalid_code`. With `"error":"invalid_payload"` the hint is still appended.
  - **`HttpRetryClient`**: a 403 and a 500 carrying the token in the body → `toString()` and `reportExtra` hold none of it.
  Red before the fix for every case.
- [x] `provider_error_summary_test.dart`: `invalid_grant` body → code; `{"errorMessage":"Token is not active"}` → null; HTML → null; `{"error":"has a space"}` → null; a 200-character `error` → null; null or empty body → null.
- [x] `tp_writeback_400_test.dart:274-296`: the write-back 400 is still Degraded. `extra['errorCode']` is `invalid_request`, `extra['statusCode']` is 400, and there is no `responseBody` (`:290` today expects the whole body).
- [x] `test/shared/source_guard/`: the helper is a pure transform, not a reporting call or a silent catch, so `source_guard.dart` and `allow_list.md` do not change. Run the folder anyway (#117).
- [x] #116: `grep -rl` under `test/` for `reportExtra`, `responseBody`, `maxReportedBodyChars`, `IntegrationApiException`, `TrainingPeaksApiException`, `FinalSurgeApiException`, `VdotApiException`, `GarminOAuthException`, `_extractErrorReason`, `exchangeCodeForToken`, `Token exchange failed`; run every file named. Tests that match an exception's `toString()` text may need the new wording.
- [x] Async paths: none added (pure transforms of responses already awaited). No retry or timeout.
- [x] `flutter analyze` clean on the touched files.

## Deploy

None (client only).

## Retest

Next test wave, Connected Apps retest ticket. Reads only: dev Sentry via the Sentry MCP, and the run's console.
- Make each token path fail once on the dev test account:
  - TrainingPeaks refresh: the lead sets the dev row's `token_expires_at` in the past and `refresh_token` to a dead value, then Sync Now;
  - V.O2 and Final Surge: a connect whose sign-in sheet is completed with a stale code (re-open the callback URL a second time), where the provider allows it;
  - Garmin: the same, where Garmin's sheet can be re-used.
- In dev Sentry, read the events those minutes produced (`search_events` on the project, the run's device id). Each holds `statusCode` and `errorCode` in `extra`, and no `responseBody`. No event's message, exception value or `extra` contains `error_description`, `Invalid refresh token`, `eyJ`, or the dead refresh token value the lead wrote. The run's `console-redacted.log` holds none of them either.
- A path that cannot be made to fail on a simulator is written as not run, with the reason; the seam tests cover it.

## Questions for Lee

1. The write-back 400 report loses its explanation. Today `reportExtra` puts TP's 400 body into Sentry, so a refused write-back says why, e.g. `"WorkoutDay is outside the editable range"` (`tp_writeback_400_test.dart:51-53`). Under the ruling it keeps only `invalid_request`. Accept that for every endpoint, or keep a description for TrainingPeaks' data endpoints (not the token endpoint), which never echo a token? Recommended: accept it. One rule everywhere; the write-back window check (`tp_writeback_service.dart`) already explains most 400s before TP is called.

**Rulings (Lee, 2026-10-09, wave 7 close).**
- Q1: one rule everywhere: status + error code only, every provider and endpoint; `tp_writeback_400_test.dart` changes with it.

## Fix notes

Code commit `abb2b9ca7` on `testing-wave/develop-2026-10/84` (base `6a0307732`, after 73).

**The helper.** `lib/features/integrations/domain/provider_error_summary.dart`: `providerErrorSummary(int? status, String? body)` returns the record `ProviderErrorSummary = ({int? status, String? errorCode})`, the same rule as `_shared/provider_error.ts` (first of `error`, `errorCode`, `code` matching `^[A-Za-z0-9_.-]{1,64}$`, else null). `providerErrorSuffix` renders ` (status: N, error: <code>)` for every `toString()`.

**Per client.**
- `IntegrationApiException`: `reportExtra` is `{statusCode, errorCode}`; `responseBody` and `maxReportedBodyChars` are gone. New getters `summary` and `redactedSuffix`. `toString()` writes the suffix in every build and never the body. `ServerException` and `ForbiddenException` use the same suffix, so a 5xx/403 now also names its code. `body` stays on the object, unread.
- TrainingPeaks: the ticket said nothing beyond item 2, but `TrainingPeaksApiException.toString()` overrides the base and appended the body in debug builds. Its override now uses the suffix (`training_peaks_api_client.dart`, outside the ticket's Touches; no message there carried a body). Refresh, code exchange, sync `_refreshToken` and the write-back sites need no call-site change.
- Final Surge: `FinalSurgeApiException.toString()` gets the same treatment. The debug `print`s of the whole body go. A 200 with `error` is `Token exchange failed: <code>` when the error is code-shaped, otherwise plain `Token exchange failed`. The data endpoint's 200-with-`ErrorMessage` (`fetchWorkoutById`) no longer folds the free text into the message ("every endpoint" ruling).
- V.O2: `_extractErrorReason(status, body)` is `summary.errorCode ?? 'HTTP <status>'`; `error_description` and the raw-text fallback are gone; the `invalid_payload` hint still fires. `VdotApiException.toString()` uses the suffix. The debug print of a failed workout GET (headers + 500 chars of body) is now path, status and code only.
- Garmin: `@visibleForTesting static GarminOAuthService.tokenExchangeFailure(http.Response)` builds `Token exchange failed: 400 invalid_grant`. The connect controller's fault, on-screen error and Mixpanel `errorMessage` inherit it unchanged.
- `test/shared/source_guard/allow_list.md`: the vdot `_extractErrorReason` catch entry went stale; it is replaced by the helper's `on FormatException` (a non-JSON body means "no code").

**Old report vs new** (TP refresh refused with Garmin's body shape):
- before: `extra: {statusCode: 400, responseBody: {"error":"invalid_grant","error_description":"Invalid refresh token: eyJyZWZyZXNoVG9rZW5WYWx1ZSI6InJ0LWxpdmUtNWYyYyJ9"}}`; error text `TrainingPeaksApiException: Token refresh failed (status: 400)\nBody: {...the same body...}` in debug builds.
- after: `extra: {statusCode: 400, errorCode: invalid_grant}`; error text `TrainingPeaksApiException: Token refresh failed (status: 400, error: invalid_grant)`. D9 holds: the report still says provider (exception class/area), endpoint (message), status and code.
- Garmin connect, before: `GarminOAuthException: Token exchange failed: 400 {"error":"invalid_grant","error_description":"Invalid refresh token: eyJ..."}`; after: `GarminOAuthException: Token exchange failed: 400 invalid_grant`.

**#77.** No async path added: the helper is a pure transform of a response already awaited, and `tokenExchangeFailure` is a pure constructor. Running twice at once or after a refresh gives the same output twice.

**Tests run** (only the files for this change, per the runbook):
- `provider_error_redaction_seam_test.dart`: 14/14 pass. Red check: with the four old client/exception files restored from HEAD, the 12 non-Garmin cases fail; the 2 Garmin cases need the new helper to compile, so they were not red-checked that way (the old message embedded `${response.body}` verbatim).
- `provider_error_summary_test.dart`: 10/10.
- `tp_writeback_400_test.dart`: 11/11 (both `responseBody` expectations replaced by `errorCode` + no `responseBody`).
- #116 grep hits and other importers of the touched files, all pass: runna_ics_client 9, sync_error_code 26, tp_ispremium_a1 7, final_surge_lookback 3, runna_sync_service 12, sync_failure_recorder_seam 20, sync_now_analytics 9, disconnect_clears_reconnect_seam 1, reconnect_unhides_seam 9, final_surge_sync_service 15, final_surge_completion_sync_seam 6, tp_refresh_requires_reconnect_seam 19, connect_cancel_is_quiet_seam 2, settings/connected_apps_garmin_reauth 3, settings/connected_apps_reconnect 6, reconnect_clears_sync_state 6, disconnect_soft_hide_state_machine 8, sync_status_write_seam 12, tp_writeback_di10 9.
- `test/shared/source_guard/`: 20/20.
- `flutter analyze` on the touched files: one info, pre-existing (`curly_braces_in_flow_control_structures` in `RateLimitException.toString`, untouched).

Retest (Sentry console and simulator) is the lead's, in the next test wave.

Seen, not fixed (out of scope): `FinalSurgeApiClient.exchangeCodeForToken` still prints the first and last 5 characters of the client secret in debug builds, and the whole secret when it is too short (`final_surge_api_client.dart:45-58`). It is the app's own secret, not a user token, but it reaches the wave's console logs.

