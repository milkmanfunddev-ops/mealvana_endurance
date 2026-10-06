# 19: Edge gateway 502 and 504

**What to build:** MEALVANA-ENDURANCE-B5, AA, AB, C1, C4, C3, C0, BM: `SentryHttpClientError` 502/504 from `functions_client.invoke` and the connected-apps row. Identify the function per issue, whether cold start, timeout or upstream, fix what is fixable, and classify the rest as Degraded in the allow-list with a reason.

**Blocked by:** 10 Contract

**Status:** done except the device check on a dead-token Garmin account (see Owed)

- [x] Each issue mapped to a function and a cause (Sentry events + prod/dev Supabase logs, read-only)
- [x] Fixes landed or the cause documented; no timeout was raised
- [ ] Issues resolved in Sentry (lead, after merge; table below)

## What the evidence said

The ticket's premise (edge functions hitting a wall-clock limit) did not hold for any issue. No
event was slow enough to hit the edge function limit: every garmin-backfill 502 came back in
0.6-2.5 s, and the search-catalog 504 in 1 s. Only half the issues are edge functions at all: B5,
C0, C1, C3 and C4 are PostgREST or GoTrue requests. The DEV-9K 529 is RevenueCat, not the AI
gateway. No Anthropic/AI-gateway 529 exists in either Sentry project, and no edge function maps a
529.

Every one of these events is the SDK's HTTP layer (`SentryHttpClient`, which reports any 5xx before
app code sees the response), so a catch site cannot downgrade them. The classification seam is
`classifyHandledHttpFailure` in `lib/shared/core/bootstrap/sentry_event_filter.dart`, which
replaces the weather-only rule.

## Issue → function → cause

| Issue | Endpoint | Cause (evidence) |
|---|---|---|
| AA (prod, 502, last 10-02) | `functions/v1/garmin-backfill`, fired from `ConnectTrainingController.build` on opening Connected Apps | The function's own 502, returned when Garmin queued nothing. Prod function logs for 10-01 and 10-02: the refresh grant came back `400 invalid_grant`, then `body_composition → 401 Token is not active`, `user_metrics`/`activities → 429 Limit 100 per 1 minute`. The athlete's Garmin connection is dead and only a reconnect fixes it. 10-02 22:30 was after a reconnect: Garmin's Cloudflare `502 Bad gateway` page plus 429s, so a real Garmin outage. |
| AB (prod, 502) | `garmin-backfill` via `syncGarmin` (pull-to-refresh) | Same function. 09-27 14:27: two calls 8 s apart, the first Garmin Cloudflare 502 + 429s, the second all three types 429. |
| DEV-5P, DEV-9M (dev, 502) | `garmin-backfill` | Same function, same family. 1.4 s round trip. |
| DEV-8H (dev, 502) | `functions/v1/kroger` (product search, 13 calls in 18 s) | `kroger_unavailable`, the kroger function's deliberate 502 when Kroger does not answer or answers non-JSON (`_shared/kroger/client.ts` on `mealplanning`). Upstream outage, shown to the user by the app's own message. |
| B5 (prod, 504, 68 ev) | Pixel 9 Pro XL, 1.27.0+112, 09-20: `rest/v1/users` POST (26 of the 30 retained events). OnePlus 8 Pro, 09-22/25: `users`, `activities`, `carb_loading_plans`, `daily_macro_targets` | Two different things. **Pixel:** one client (user `ba60cdee…`) sent **7,224 upserts to `users` in 2.5 minutes** (prod edge logs, 12:12-12:14; each followed by the `User profile updated successfully` breadcrumb with `needsUpload: false`, so a write-through `updateUserProfile` caller in a loop). Same-row upserts queued on row locks (Postgres logs `still waiting for ShareLock … after 2405 ms`) until Supabase's gateway answered 504 after 38-52 s. A client write storm; see Owed. **OnePlus:** the 504s came back in about 1 s and **never reached Supabase**: requests from the same minutes are in the edge log with 200/201, the 504'd ones are absent. A network middlebox on the athlete's side. |
| BM (prod, 504) | `functions/v1/search-catalog` (OnePlus 8 Pro, 09-25) | Same OnePlus middlebox: about 1 s, absent from the Supabase edge log, while the surrounding search-catalog calls are 200. |
| C0 (prod, 504) | `rest/v1/app_config` (OnePlus 8 Pro, 09-09) | Same device family and shape. |
| C1 (prod, 504) | `auth/v1/token?grant_type=refresh_token` (09-09, 09-14) | Supabase gateway blip. 09-14 13:00 and 13:15: every request from that client got 504 after about 5.2-5.7 s (token refresh, `education_content`, `activities`, `daily_macro_targets`, `token_wallets`, `template_foods`), and the prod edge log records those 504s itself (5 at 13:00, 6 at 13:15, nothing in the minutes between). Platform side, transient. |
| C3, C4 (prod, 504) | `rest/v1/template_foods` (09-14 13:15) | The same 13:15 blip. |
| DEV-8N (dev, 500) | `auth/v1/signup` | Test account `paywall08-…@example.com`. The dev email provider refuses `example.com` (`gomail: 550 Invalid to field`), and GoTrue answers 500 `unexpected_failure`. Test data, not an app bug. |
| DEV-8V (dev, 500) | `auth/v1/user` PUT (email set at onboarding save) | Same 550 rejection of an `example.com` address (dev auth log 09-21 23:29). |
| DEV-9K (dev, 529, 4 ev, 3 users, all 09-26) | `api.revenuecat.com/v1/subscribers/<id>/attributes`, native iOS SDK | RevenueCat's API answered 529 to a subscriber-attribute sync (envoy upstream time 13 ms: an immediate refusal, not a timeout). One event came right after `delete-user`, posting attributes for the previous subscriber id. Captured by the native Cocoa SDK's failed-request capture (`mechanism: HTTPClientError`), so it never passes through the Dart `beforeSend`. The RC SDK retries attribute sync itself. Not the AI gateway. |

## Fix

**garmin-backfill answers per cause** (`supabase/functions/garmin-backfill/outcome.ts`, wired in
`index.ts`). When Garmin queued nothing:

- any `401` (dead token) → **409** `code: garmin_reauth_required`
- every type `429` → **429** `code: garmin_rate_limited` + `Retry-After: 60`
- anything else (a Garmin 5xx, a mix, every fetch threw) → **502** `code: garmin_unavailable`, as before.

A dead token or a throttle no longer reaches Sentry as a server fault, because the app's HTTP layer
reports 5xx only. The edge function still records each Garmin rejection as a warning and console
line (D9: server log). No timeout was touched, and no retry was added: Garmin's 429 is a
per-minute quota, so an immediate retry would only burn more of it, and the app already
reschedules a transient failure for about 30 minutes later.

- Deno: `supabase/functions/garmin-backfill/outcome.test.ts` (5 cases built from the prod log
  status maps); the whole folder is green (`deno test --allow-all`, 6 files, 38 steps), and so is
  `_shared/sentry_coverage.test.ts`.
- **Deployed to DEV** (`./scripts/deploy_dev.sh garmin-backfill`). Before the deploy, dev was
  running the same code as `sentry` HEAD (read back via the Supabase MCP). A boot smoke with the
  anon key reaches the handler and gets `401 Invalid or expired authentication token`. Prod not
  deployed.

**The app treats a dead token as Degraded.** In `ConnectTrainingController.triggerGarminBackfill`,
a `FunctionException` that is 409 with `garmin_reauth_required` is reported as
`report.degraded(area: garmin, 'garmin-backfill 409: Garmin token expired, athlete must reconnect
Garmin')` and does not schedule the 30-minute retry. Before this change, any non-502/429 status
fell through to `report.fault`. New helper: `isGarminReauthRequired`.

- Test: `test/features/integrations/garmin_backfill_failure_report_test.dart`. It drives the real
  notifier through a real `FunctionsClient` whose HTTP layer returns the body the function sends.
  It was red with the reauth branch disabled (the old fall-through to fault) and is green now. An
  unexpected 500 still records a Fault.

**SDK-reported gateway failures are classified per endpoint**
(`classifyHandledHttpFailure`, `sentry_event_filter.dart`; two new `ExpectedFailure` reasons in
`expected_failures.dart`):

- 502 from `functions/v1/garmin-backfill` or `functions/v1/kroger` → `upstream_unavailable`
- 504 from any `*.supabase.co` endpoint → `gateway_timeout`
- `get-weather-forecast`, any status → `handled_fallback` (unchanged)
- each downgraded event also gets `http_endpoint:<last path segment>` (`garmin-backfill`, `users`,
  `token`), so the reason names the function or table.
- Every other SDK-reported 5xx stays a Fault: a 500 from garmin-backfill, a 502 from a function
  with no upstream rule, and a 504 from a non-Supabase host each have a negative test.

- Test: `test/shared/core/bootstrap/sentry_event_filter_test.dart`, group
  `SDK-reported HTTP failures (ticket 19)`, 8 cases. The events take the shape
  `FailedRequestClient` builds, with URLs and statuses from the real events. 4 cases were red
  against the old filter; all are green now.
- Docs: `docs/technical/sentry-integration.md` §beforeSend.

Verification run: `dart analyze` on every changed Dart file (clean, apart from one `avoid_print`
info at `connect_training_controller.dart:1693` that was already there),
`flutter test test/shared/source_guard` plus the two test files above (53 passed). No full suite.

## Owed

- **Device check not run:** a dead-token Garmin account on dev, opening Connected Apps, should
  produce a `garmin-backfill 409` Degraded event and no Fault. It needs a dev user whose Garmin
  refresh token is revoked. The unit seam covers the logic; nobody has run it on a device.
- **Prod deploy of garmin-backfill** waits for the next bundle (playbook). Until it ships, prod
  keeps answering 502 for dead tokens. The app's filter already downgrades those 502s, so the
  Sentry noise stops with the app build either way.
- **Reconnect prompt (product):** after a 409, `syncGarmin` still shows "Weight/body data sync is
  temporarily delayed, we'll retry automatically", which is wrong for a dead token. The athlete
  should be told to reconnect Garmin. That copy belongs in the content system and needs a product
  call, so it is not done here. The function could also mark the integration as needing reauth
  server-side.
- **B5 write storm (new ticket):** one 1.27.0+112 client sent 7,224 `users` upserts in 2.5 min on
  2026-09-20. The breadcrumbs point at a write-through `UserRepository.updateUserProfile` caller
  (`needsUpload: false`) firing in a loop, which rules out `reconcileAppVersion` (that one uses
  `needsUpload: true`). The candidates are the settings/sweat/nutrition-profile saves, the
  onboarding plan-edit save and the fresh-login profile update. Not found within this ticket, and
  prod has not repeated it since (no burst over 20/min/user on 10-05). The 504s it caused are now
  `gateway_timeout` warnings, so a repeat stays visible but will not alert. It needs its own ticket
  with a debounce/in-flight guard in `updateUserProfile`.
- **Garmin 429 quota:** Garmin answers `Limit 100 per 1 minute` with one identifier on every prod
  backfill, even at about 3 backfill calls per hour. The quota is probably keyed to the app's
  consumer key (an evaluation-tier limit?). Worth asking Garmin, because prod backfill almost never
  succeeds in the sampled days.
- **DEV-9K:** native iOS failed-request events skip the Dart filter. If RevenueCat 529s recur in
  prod, set `captureNativeFailedRequests` or add a native-side rule. One dev issue (4 events) does
  not justify that yet.

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-AA | resolve-as-degraded | garmin-backfill 502 = Garmin refused all types (dead token 401 / Garmin 429 / Garmin Cloudflare 502). Function now answers 409/429/502 per cause; app downgrades garmin-backfill 502 to upstream_unavailable and a 409 to Degraded. Ticket 19. |
| MEALVANA-ENDURANCE-AB | resolve-as-degraded | Same as AA (garmin-backfill via syncGarmin). Ticket 19. |
| MEALVANA-ENDURANCE-B5 | resolve-as-degraded | Supabase 504s: Pixel events were a one-off client write storm (7,224 users upserts in 2.5 min, row-lock pile-up; follow-up ticket); OnePlus events never reached Supabase (client-side middlebox). Now gateway_timeout warnings. Ticket 19. |
| MEALVANA-ENDURANCE-BM | resolve-as-degraded | search-catalog 504 never reached Supabase (OnePlus client network, 1 s). gateway_timeout. Ticket 19. |
| MEALVANA-ENDURANCE-C0 | resolve-as-degraded | app_config 504, same OnePlus client-side middlebox. gateway_timeout. Ticket 19. |
| MEALVANA-ENDURANCE-C1 | resolve-as-degraded | auth token refresh 504 during a Supabase gateway blip (09-14 13:00/13:15, recorded in Supabase edge logs). gateway_timeout. Ticket 19. |
| MEALVANA-ENDURANCE-C3 | resolve-as-degraded | template_foods 504 in the same 09-14 13:15 Supabase gateway blip. gateway_timeout. Ticket 19. |
| MEALVANA-ENDURANCE-C4 | resolve-as-degraded | Same as C3. Ticket 19. |
| MEALVANA-ENDURANCE-DEV-5P | resolve-as-degraded | garmin-backfill 502, same family as AA. Ticket 19. |
| MEALVANA-ENDURANCE-DEV-9M | resolve-as-degraded | garmin-backfill 502, same family as AA. Ticket 19. |
| MEALVANA-ENDURANCE-DEV-8H | resolve-as-degraded | kroger 502 = kroger_unavailable (Kroger upstream did not answer); app shows its own message. upstream_unavailable. Ticket 19. |
| MEALVANA-ENDURANCE-DEV-8N | resolve | Test artifact: signup with an example.com address; dev email provider refuses it (550) and GoTrue answers 500. Ticket 19. |
| MEALVANA-ENDURANCE-DEV-8V | resolve | Test artifact: PUT auth/v1/user setting an example.com email, same 550. Ticket 19. |
| MEALVANA-ENDURANCE-DEV-9K | resolve | RevenueCat API 529 on native subscriber-attribute sync (dev sandbox, 09-26 only), not the AI gateway; RC SDK retries. Native capture bypasses the Dart filter; revisit if it recurs in prod. Ticket 19. |
