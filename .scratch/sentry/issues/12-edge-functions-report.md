# 12: Edge functions report

**What to build:** Every Supabase edge function reports to Sentry. First, prove the pipeline: a deliberate throw in one function arrives in the dev project under environment `edge-dev`, since no edge event has ever arrived despite the secrets being set (check the secret value, the flush, outbound access). Then: the wrapper runs each request under its own isolation scope, tags function name and method, and flushes before returning; the shared `serverError()` captures the error it is given, `errorResponse()` captures when handed an error object or a 5xx status and breadcrumbs a 4xx without one; remaining raw `console.error` catches capture explicitly or route through the helpers; ensure-credits and revenuecat-webhook are wrapped; `@sentry/deno` moves to the latest 8.x; traces sample rate is 0; the nightly retention sweep function sends a cron check-in. A Deno test runs every handler through the wrapper with a fake Sentry client and an error-forcing request and asserts one capture under its own scope, and a scan asserts every function's entry uses the wrapper.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] A deliberate throw deployed to dev shows in the dev project under environment `edge-dev` with tag `component:edge_function`; the ticket records the event id and what, if anything, had blocked edge events before
- [ ] Secrets on both Supabase projects set `SENTRY_ENVIRONMENT` to `edge-dev` and `edge-prod`
- [ ] All functions, including ensure-credits and revenuecat-webhook, use the wrapper; each request runs under `withIsolationScope`
- [ ] `serverError()` and `errorResponse()` capture as specified; no catch in any function is `console.error`-only
- [ ] `@sentry/deno` is on the latest 8.x; edge traces sample rate 0
- [ ] The retention sweep sends a cron check-in (in progress / ok / error) on each run
- [ ] The Deno coverage test and wrapper test exist and pass locally; the existing edge tests still pass
- [ ] Changed functions deployed to dev with the dev deploy script; prod untouched
