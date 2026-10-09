# 76: Garmin functions log a provider's status and error code, never its error body

**Status:** landed-pending-merge (wave 8, 2026-10-09, 9bc706bfc)
**Labels:** fix, round:develop-2026-10, area:integrations, area:server, area:privacy
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Finding 69-012; TRIAGE.md rulings of 2026-10-09
**Blocked by:** nothing. Server only; no file shared with 74, 75 or 77, or with 71-73.
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

Line numbers are from code at `84615131`.

## Findings

- **69-012 · garmin-backfill prints Garmin's invalid_grant description, which carries the refresh token value, into the dev function logs.** Run 69 opened Connected Apps on the dev test account with a dead Garmin link; the app fired garmin-backfill on its own. Dev `function_logs` at 23:38:07.982Z: `[garmin-backfill] Token refresh failed (400): {"error":"invalid_grant","error_description":"Invalid refresh token: eyJ…=="}`. The base64 decodes to JSON holding `refreshTokenValue` and `garminGuid`. That token was already dead; the same line prints a live one on any other refresh failure. Evidence: `runs/69/edge-23-16-to-23-44.txt` (garmin-backfill lines at 23:38:07-08Z, value cut).

## Fix

**Ruling (2026-10-09):** log only the status and the error code, never the description or the body. Cover every function that logs a provider token-refresh or OAuth error body, with one shared redaction helper.

**Where provider bodies reach a log today (from code; `grep -rn "\.text()\|access_token\|refresh_token" supabase/functions` outside `_archived/` and tests):**

| Site | What it writes | Reached by |
|---|---|---|
| `_shared/garmin/token.ts:107-111` | `console.error` of Garmin's token-endpoint body (300 chars): **the 69-012 leak** | `ensureFreshGarminToken`: garmin-backfill (`garmin-backfill/index.ts:207`); `deregisterGarminForUser` (`token.ts:182`): garmin-user-mapping (`garmin-user-mapping/index.ts:105`), delete-user (`delete-user/index.ts:46`) |
| `_shared/garmin/token.ts:137` | the PostgREST error of the refreshed-token write, whole | same |
| `_shared/garmin/token.ts:177`, `:242`, `:245` | the whole PostgREST error of the token read and of the requires_reauth write | same, plus garmin-backfill's `markGarminRequiresReauth` |
| `garmin-user-mapping/index.ts:54-60` | `console.error` of Garmin's whole `/user/id` answer to a Bearer token | garmin-user-mapping (connect) |
| `garmin-backfill/index.ts:251-262` | Garmin's backfill answer (500 chars) into a Sentry warning's `extra.body`, and into `errors`, which `errorResponse` (`_shared/responses.ts:37-60`) sends to Sentry / breadcrumbs as `details` and back to the app | garmin-backfill |

A PostgREST error's `details` can hold "Failing row contains (…)" for a constraint violation on `integrations`, which is the whole row, tokens included. That is why the DB-error sites are in scope.

Checked and left alone (from code): training-peaks, finalsurge and vdot have **no edge function**. Their OAuth and refresh run on the device (`lib/features/integrations/data/training_peaks_api_client.dart:93-98, :139-145`, `final_surge_api_client.dart:75-112`, `vdot_api_client.dart`, `garmin_oauth_service.dart:270-273`), so they are not in this ticket (Question 1). garmin-push refreshes no token and drops `userAccessToken` before it stores a payload (`garmin-push/index.ts:1206`). Its fanout warning (`:159-165`) carries our own relay's body, not a provider's. garmin-oauth-callback only redirects (`garmin-oauth-callback/index.ts`, no log). `_shared/garmin/onesignal.ts:140` and `_shared/revenuecat/client.ts:55` are not provider OAuth.

1. **One helper.** New `supabase/functions/_shared/provider_error.ts`:
   - `providerErrorSummary(status: number, body: string): { status: number; error_code: string | null }`. Parse `body` as JSON. Take the first of `error`, `errorCode` or `code` that is a string matching `^[A-Za-z0-9_.-]{1,64}$`. Anything else gives `null`: a non-JSON body, an `error` with spaces, or only an `error_description` / `message` / `errorMessage`. Never returns or logs `error_description`, `message`, `errorMessage`, the raw body or any substring of it.
   - `dbErrorSummary(err: unknown): { code: string | null; message: string | null }`, PostgREST `code` and `message` only, never `details` or `hint`; a thrown `Error` gives `name: message`.
   Doc comment: the ruling, and why (69-012; the Failing-row case).
2. **`_shared/garmin/token.ts`.**
   - `:107-111` becomes `console.error(\`${prefix} Token refresh failed\`, providerErrorSummary(resp.status, await resp.text()))`, e.g. `{"status":400,"error_code":"invalid_grant"}`.
   - `:137`, `:177`, `:242` log `dbErrorSummary(…)`.
   - `:142` and `:245` (thrown errors) log `dbErrorSummary(err)`, so a fetch error's message is kept and nothing else.
   - The doc comment at `:156` already promises "never the token"; it now holds for the refresh step too.
3. **`garmin-user-mapping`.** Move `verifyGarminUserId` (`index.ts:46-73`) into `garmin-user-mapping/verify.ts`, beside `delete.ts`, with `fetch` injectable, as `delete.ts` does for its deps. On `!response.ok` log `providerErrorSummary(response.status, await response.text())`. `index.ts` imports it. The mismatch log (`:64-70`) carries ids only and stays.
4. **`garmin-backfill`.** Add to `garmin-backfill/outcome.ts` a pure `describeBackfillRejection(status: number, text: string): { summary: ProviderErrorSummary; tokenInactive: boolean }`, using `isGarminTokenInactive(status, text)` (`_shared/garmin/token.ts:210-213`) on the raw text in memory. In `index.ts:251-262`:
   - `errors[summaryType] = summary`, typed `Record<string, ProviderErrorSummary | string>`; the thrown-fetch branch `:270` stays `String(err)`;
   - `tokenInactive ||= …`;
   - the Sentry warning's `extra` becomes `{ userId, summaryType, status, error_code, token_inactive }`, with no `body`.
   The 409 answer keeps `code: garmin_reauth_required` and `requires_reauth: true` in `additionalData` (`:291-297`). The app reads only those (`connect_training_controller.dart:55-58, :1333-1336`), never `details`, so the app needs no change.

## Touches

supabase/functions/_shared/provider_error.ts (new)
supabase/functions/_shared/provider_error.test.ts (new)
supabase/functions/_shared/garmin/token.ts
supabase/functions/_shared/garmin/token.test.ts
supabase/functions/garmin-user-mapping/verify.ts (new)
supabase/functions/garmin-user-mapping/index.ts
supabase/functions/garmin-user-mapping/index.test.ts
supabase/functions/garmin-backfill/outcome.ts
supabase/functions/garmin-backfill/outcome.test.ts
supabase/functions/garmin-backfill/index.ts

10 files. No Dart, no SQL, no migration.

## Tests

- [x] **Seam, the 69-012 line** (`_shared/garmin/token.test.ts`, with its `captureConsole` (`:104-120`) and `fakeFetch`). `ensureFreshGarminToken` on an expired row, with the token endpoint answering 400 and Garmin's real body shape: `{"error":"invalid_grant","error_description":"Invalid refresh token: " + btoa(JSON.stringify({refreshTokenValue: "rt-live-5f2c", garminGuid: "g-guid-1"}))}`. The captured lines contain `400` and `invalid_grant`. None contains `rt-live-5f2c`, the base64 string or any 12-character slice of it, `Invalid refresh token`, or `error_description`. The stale token is still returned. Red before the fix.
- [x] Same file: the persist step's update answering `{code: '23502', message: 'null value in column …', details: 'Failing row contains (… rt-live-5f2c …)'}`: the line holds `23502` and not `rt-live-5f2c`. The same for `markGarminRequiresReauth` and the deregistration read.
- [x] `provider_error.test.ts`: the invalid_grant body; `{"errorMessage":"Token is not active"}` → `error_code: null`; non-JSON HTML (Garmin's 502) → `null`; `{"error":"has a space rt-live"}` → `null`; `{"code":"rate_limited"}` → `rate_limited`; a 200-character `error` → `null`. `dbErrorSummary` drops `details` and `hint`.
- [x] `garmin-user-mapping/index.test.ts`: replace its local mirror of `verifyGarminUserId` (`:31-…`) with the real `verify.ts`. A 401 whose body echoes the Bearer token logs neither the token nor the body, and the function still answers 401.
- [x] `garmin-backfill/outcome.test.ts`: `describeBackfillRejection(401, '{"errorMessage":"Token is not active"}')` → `tokenInactive: true`, summary `{status: 401, error_code: null}`; `429` with Garmin's throttle text → not inactive, no text in the summary.
- [x] `deno test --allow-all` (never `--allow-sys`, #109) on `supabase/functions/_shared/provider_error.test.ts`, `_shared/garmin/`, `garmin-backfill/`, `garmin-user-mapping/`, `delete-user/`. `deno check` on the three `index.ts`.
- [x] Async paths: none added. Each log is a pure transform of a response already awaited. No retry or timeout.

## Deploy

The lead, to dev, from the merged tree: `./scripts/deploy_dev.sh garmin-backfill garmin-user-mapping delete-user` (every function that imports `_shared/garmin/token.ts`; garmin-backfill and garmin-user-mapping change themselves). No SQL.

## Retest

Next test wave, Connected Apps retest ticket (server side, read at the close):
- **69-012:** with the dev test account's Garmin row active and its token dead (the lead sets `last_sync_status` back to `success` on dev first, so the app fires the backfill), open Connected Apps once. In dev `function_logs` for garmin-backfill at that minute, the refresh line reads `[garmin-backfill] Token refresh failed { status: 400, error_code: "invalid_grant" }` (Deno prints the logged object in its own inspect format, not JSON; match on `Token refresh failed` and `invalid_grant`). No line holds `error_description`, `Invalid refresh token`, `eyJ` or any base64 run. Dev Sentry's garmin-backfill warning, if any, has no `body` in `extra`. If 77 has landed, the app skips the backfill while the row says `requires_reauth`; the lead then calls garmin-backfill once with the test account's session (curl) to produce the line.

## Questions for Lee

1. The device side has the same class of leak to Sentry. `IntegrationApiException.reportExtra` (`lib/features/integrations/domain/integration_exceptions.dart:161-176`) sends up to 1000 characters of a provider's body as `responseBody`, including TrainingPeaks' and Final Surge's token-refresh and token-exchange refusals (`training_peaks_api_client.dart:139-145`, `final_surge_api_client.dart:88-112`). `GarminOAuthException` puts Garmin's token-exchange body in its message (`garmin_oauth_service.dart:270-273`). Fix them the same way (status + error code only) in a small client ticket in this wave? Recommended: yes, as its own ticket. `integration_exceptions.dart` is in 73's Touches, so it runs after 73, not inside 76.

**Rulings (Lee, 2026-10-09, wave 7 close).**
- Q1: the client leak is a separate ticket 84 (cut 2026-10-09), fix wave 8 after 73.

## Fix notes

Landed in `9bc706bfc` on `testing-wave/develop-2026-10/76` (base `0e6aa1cf7`), wave 8, 2026-10-09.

**What changed.**
- `_shared/provider_error.ts` (new) is the one redaction rule. `providerErrorSummary(status, body)` gives `{status, error_code}`: the first of `error`, `errorCode`, `code` that is a string matching `^[A-Za-z0-9_.-]{1,64}$`, else `null`. `dbErrorSummary(err)` gives `{code, message}` from a PostgREST error (never `details` or `hint`), `name: message` from a thrown `Error`, nulls for anything else. Ticket 84 mirrors this rule on the device.
- `_shared/garmin/token.ts`: the refused refresh logs `providerErrorSummary`; the refreshed-token persist, the deregistration read, and both `markGarminRequiresReauth` paths log `dbErrorSummary`; the thrown refresh logs `dbErrorSummary(err)`.
- `garmin-user-mapping/verify.ts` (new): `verifyGarminUserId(accessToken, expectedId, fetchFn = fetch)` returns `{ok:true}` or `{ok:false, status: 401|403, message}`; a refusal logs `providerErrorSummary`. `index.ts` imports it and turns a failure into `errorResponse(message, status)` (same answers as before: 401 / 403). The mismatch log (ids only) is unchanged.
- `garmin-backfill/outcome.ts`: `describeBackfillRejection(status, text)` gives `{summary, tokenInactive}`; the text is only read in memory by `isGarminTokenInactive`. `index.ts` stores `summary` in `errors` (so the `details` sent to Sentry and the app holds `{status, error_code}` per type), and the Sentry warning's `extra` is `{userId, summaryType, status, error_code, token_inactive}` with no `body`. The 409 `code: garmin_reauth_required` / `requires_reauth: true` answer is unchanged.

**Log line, old versus new** (69-012, garmin-backfill, refresh refused):
- Old: `[garmin-backfill] Token refresh failed (400): {"error":"invalid_grant","error_description":"Invalid refresh token: eyJ…=="}`
- New: `[garmin-backfill] Token refresh failed { status: 400, error_code: "invalid_grant" }`

The Retest line above now names Deno's inspect format, since `console.error` of an object does not print JSON.

**Deploy (the lead's, to dev, from the merged tree):** `./scripts/deploy_dev.sh garmin-backfill garmin-user-mapping delete-user`. delete-user changes only through `_shared/garmin/token.ts`. No SQL.

**#77, twice at once or after a retry.** No async path was added and none changed order or count: each change is a pure transform of a response or error already awaited, and the function answers the same status as before. Two concurrent garmin-backfill calls on a dead token each refresh, each log one redacted line, and each mark `requires_reauth` (the same idempotent update as before). A Garmin retry or a re-triggered backfill logs the same redacted line again. The garmin-user-mapping upsert verification is a single read-only GET to Garmin; repeating it changes nothing.

**D9 / #117.** No early return or catch was added. The `JSON.parse` catch inside `providerErrorSummary` is not a swallowed failure: a non-JSON body is an expected input and shows in the log as `error_code: null`. The existing silent paths all still log, now redacted.

**Tests run** (`deno test --allow-all`, no `--allow-sys`), all green, 93 tests / 215 steps, 0 failed:
- `_shared/provider_error.test.ts`: 11 passed (new).
- `_shared/garmin/` (activity_completion 3, auth 1, mappers 2, matcher 42, matcher_executor 6, onesignal 2, push_log 4, token 5 suites / 20 steps): all passed. token.test.ts's new `redaction (ticket 76)` suite (5 steps) was red before the token.ts change and green after.
- `garmin-backfill/` (index 1, outcome 7): all passed.
- `garmin-user-mapping/index.test.ts`: 2 suites passed; the local mirror of `verifyGarminUserId` is gone and the tests drive the real `verify.ts`, with a new 401-echoes-the-token case.
- `delete-user/index.test.ts`: 7 passed.
- `deno check` on `garmin-backfill/index.ts`, `garmin-user-mapping/index.ts`, `delete-user/index.ts`, `garmin-user-mapping/verify.ts`: clean.
- `deno lint` on the ten touched files: one finding, `buildSupabaseDeleteStub` unused in `garmin-user-mapping/index.test.ts:128`, which is already there at base `0e6aa1cf7`; left alone.

**Left for the lead.** Dev deploy (above) and the 69-012 log check in the next test wave's Connected Apps retest. Not touched, outside the ticket's table: garmin-backfill's integrations-read failure and garmin-user-mapping's upsert failure still pass the whole PostgREST error to `errorResponse` as Sentry `cause` (a select error carries no row; the mapping row holds no tokens since Q-INT8).
