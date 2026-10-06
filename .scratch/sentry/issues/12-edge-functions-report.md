# 12: Edge functions report

**What to build:** Every Supabase edge function reports to Sentry. First, prove the pipeline: a deliberate throw in one function arrives in the dev project under environment `edge-dev`, since no edge event has ever arrived despite the secrets being set (check the secret value, the flush, outbound access). Then: the wrapper runs each request under its own isolation scope, tags function name and method, and flushes before returning; the shared `serverError()` captures the error it is given, `errorResponse()` captures when handed an error object or a 5xx status and breadcrumbs a 4xx without one; remaining raw `console.error` catches capture explicitly or route through the helpers; ensure-credits and revenuecat-webhook are wrapped; `@sentry/deno` moves to the latest 8.x; traces sample rate is 0; the nightly retention sweep function sends a cron check-in. A Deno test runs every handler through the wrapper with a fake Sentry client and an error-forcing request and asserts one capture under its own scope, and a scan asserts every function's entry uses the wrapper.

**Blocked by:** None (can start immediately)

**Status:** built on dev (worktree-sentry-12); prod secret + prod deploy owed at release

- [x] A deliberate throw deployed to dev shows in the dev project under environment `edge-dev` with tag `component:edge_function`; the ticket records the event id and what, if anything, had blocked edge events before
- [ ] Secrets on both Supabase projects set `SENTRY_ENVIRONMENT` to `edge-dev` and `edge-prod` — dev done; prod still reads `production` (owed, see build notes)
- [x] All functions, including ensure-credits and revenuecat-webhook, use the wrapper; each request runs under `withIsolationScope`
- [x] `serverError()` and `errorResponse()` capture as specified; no catch in any function is `console.error`-only
- [x] `@sentry/deno` is on the latest 8.x; edge traces sample rate 0
- [x] The retention sweep sends a cron check-in (in progress / ok / error) on each run
- [x] The Deno coverage test and wrapper test exist and pass locally; the existing edge tests still pass
- [x] Changed functions deployed to dev with the dev deploy script; prod untouched

## Build notes (2026-10-06, worktree-sentry-12)

**Proof event.** `5eb61fcfe37a422293d3cc658158bb63` (issue MEALVANA-ENDURANCE-DEV-A4), dev project,
environment `edge-dev`, tags `component:edge_function`, `method:POST`, `region:us-east-1`, SDK
`sentry.javascript.deno` 8.55.2, runtime `supabase-edge-runtime-1.77.0 (Deno 2.1.4)`. Fired by
`POST /functions/v1/ensure-credits` with the probe header; two more at 12:29:59Z (ensure-credits,
get-foods) after the full redeploy carry the `edge_function:<name>` tag.

**Root cause of the silence.** Not the DSN, not the import, not the flush, not outbound access: the
dev secret's digest matched the dev DSN exactly, and two `sentry.javascript.deno` events (the
ai_cost warnings, 2026-09-22) had already reached the dev project from the hosted runtime via the
esm.sh import. Nothing with `component:edge_function` ever arrived because the wrapper only captured
an exception that *escaped* the handler, and every handler catches everything itself and answers
through `serverError()` / `errorResponse()` / a raw 500 — which only `console.error`'d. Second
factor: `SENTRY_ENVIRONMENT` was `development` (dev) and `production` (prod), so even a delivered
edge event would not have filed under `edge-dev`. Found on the way: Sentry drops a tag key literally
named `function` (the first probe arrived without it), so the name is tagged `edge_function`.

**What changed.**
- `_shared/sentry.ts`: `npm:@sentry/deno@^8.55.2` (was esm.sh 8.53.0); `tracesSampleRate: 0`;
  `withSentry(name, handler)` runs each request under `withIsolationScope` with an
  AsyncLocalStorage context strategy installed from `@sentry/core` (the Deno SDK ships the stack
  strategy, which leaked scope between concurrent requests — reproduced locally), tags
  `edge_function` / `method` / `component`, flushes in `finally`; helpers `captureEdgeError`,
  `captureEdgeMessage`, `edgeBreadcrumb`, `edgeCheckIn`; test seams `setSentryClientForTesting`,
  `wrappedHandlers`; probe header `x-sentry-probe`, honoured only when it equals the
  `SENTRY_PROBE_TOKEN` secret (set on dev, stored in `secrets/sentry_probe.env`; never set on prod).
  The one-argument legacy form stays only so the FROZEN `calculate-daily-macros` compiles untouched.
- `_shared/responses.ts`: `serverError(error, fallback, publicMessage?)` captures; `errorResponse(
  message, status, details, additionalData, cause?)` captures with a cause or a 5xx, breadcrumbs a
  4xx without one.
- Every non-frozen function (32) now enters through `serve(withSentry('<folder>', …))`;
  ensure-credits and revenuecat-webhook newly wrapped. All `console.error`-only catches in the
  32 index.ts files and 20 `_shared` modules route through the helpers; the 32 `console.error`
  lines left are expected 4xx client faults (auth, validation, parse) or context before a throw.
- `raw-retention-alert`: cron check-in `in_progress` → `ok`/`error` for monitor
  `raw-retention-sweep` (`17 3 * * *`, 30-minute margin, upserted by the SDK), gated by
  `SENTRY_CRON_MONITORS=1` so dev does not spend the free plan's one monitor. Accepts the new
  `{audit, sweep_status, sweep_error, alerted}` body and the legacy bare audit row.
- Migration `20261006120000_raw_retention_sweep_checkin.sql`: the pg_cron wrapper posts on every
  run (not only on alert) and reports a sweep failure as `sweep_status: error` instead of
  re-raising (an exception would roll the pg_net POST back). Applied to dev via the Management API;
  verified `has_new_body = true`, cron job intact. Vault secrets were already seeded on dev.
- Runner `run-algorithm-tests.sh` gains `--allow-sys` (the coverage test imports every function and
  the AI SDK reads the hostname at import time); TESTING.md says so.

**Tests.**
- `deno test --allow-read --allow-write --allow-env --allow-sys --node-modules-dir=none
  supabase/functions/_shared/sentry.test.ts` → `ok | 16 passed | 0 failed`
- `… _shared/sentry_coverage.test.ts` → `ok | 3 passed | 0 failed` (scan of 32 folders; each
  handler driven through the wrapper with the fake client: one capture, own scope, name tag, flush)
- `bash supabase/functions/run-algorithm-tests.sh` → `Discovered: 99 files (94 local, 5 remote,
  0 quarantined) · Ran: 94 · Passed: 94 · Failed: 0`
- `deno check` on all 32 index.ts: only pre-existing type errors remain (get-weather-forecast 12,
  search-public-events 2, sync-all-data 30 (was 32), upload-all-data 9 (was 17),
  upsert-user-profile 2), counts compared against the untouched `sentry` branch.

**Deployed to dev** (`./scripts/deploy_dev.sh`): all 32 non-frozen functions. Dev checks after the
deploy: probe → 500 + event on ensure-credits and get-foods; control call without the header → 401
and no event; `raw-retention-alert` quiet-night report → 200 `{"sweep":"ok","alerted":false}`,
bad token → 401; `verify_jwt` still false on revenuecat-webhook and raw-retention-alert.
Dev secrets set: `SENTRY_ENVIRONMENT=edge-dev` (digest verified), `SENTRY_PROBE_TOKEN`.

**Owed.**
- Prod (at release, from trunk, read-only confirmed today): `SENTRY_ENVIRONMENT` is `production`
  → set `edge-prod`; set `SENTRY_CRON_MONITORS=1` so the one free monitor lands on prod; apply the
  migration; deploy the 32 functions. Do NOT set `SENTRY_PROBE_TOKEN` on prod.
- A real nightly check-in has not been observed anywhere yet (dev is gated off by design); the
  first prod run after the cut creates the monitor. Watch 03:17 UTC + 30 min.
- `.scratch/sentry/research/sentry-plan-and-supabase.md` suggested checking in from SQL; the spec
  (and this build) checks in from the edge function — the research note is stale on that point.
- The probe issue MEALVANA-ENDURANCE-DEV-A4 is left open as the proof record; resolve when read.
- The `function` → `edge_function` tag name is a deviation from the spec's wording ("tags function
  name"); the name is still tagged, under a key Sentry keeps.

## Prod rollout (2026-10-06, Lee's instruction, lead session)

- Prod secrets set: `SENTRY_ENVIRONMENT=edge-prod`, `SENTRY_CRON_MONITORS=1` (digests verified). `SENTRY_PROBE_TOKEN` NOT set on prod; a probe header against prod ensure-credits answers 401.
- Migration `20261006120000_raw_retention_sweep_checkin.sql` applied to prod via the Management API; `raw_retention_sweep_and_notify` body verified to carry `sweep_status`; pg_cron job `raw-retention-sweep` (`17 3 * * *`) still calls it. First check-in expected 03:17 UTC; the monitor is created by that run.
- All 32 non-frozen functions deployed to prod with `scripts/deploy_prod.sh` (counters bumped; `calculate-daily-macros` FROZEN untouched). Note: `vana-action`, `vana-chat`, `vana-day-notes` reached prod for the first time (version 1); they require a user JWT and the app does not call them in prod yet.
- Smoke: raw-retention-alert bad token 401, get-weather-forecast unauthenticated 401, ensure-credits with the probe header 401.
- Codemagic already carried `SENTRY_AUTH_TOKEN` in `mealvana_dev` and `mealvana_prod`. Vercel now has `SENTRY_AUTH_TOKEN` + `SENTRY_PROJECT` for Production (`mealvana-endurance`) and Preview (`mealvana-endurance-dev`); the token is the personal sentry-cli token from `~/.sentryclirc` because org auth tokens cannot be minted via the API with a user token.
