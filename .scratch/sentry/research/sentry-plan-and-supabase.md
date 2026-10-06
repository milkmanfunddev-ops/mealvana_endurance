# Sentry plan, alert noise, and Supabase edge-function monitoring (2026-10-05)

Primary sources only; repo facts from `supabase/migrations`, `.github/workflows`, `supabase/functions/_shared/sentry.ts`.

## 1. Sentry Developer (free) plan, and Team for comparison

| Item | Developer (free) | Team ($26/mo annual, $29 monthly) |
|---|---|---|
| Errors | 5k / month | 50k / month |
| Spans (tracing) | 5M | 5M |
| Session replays | 50 | 50 |
| Profile hours | none included; profile hours are "available only through PAYG", and PAYG is paid-plans-only, so effectively 0 on free | PAYG only |
| Attachments | 1 GB | 1 GB |
| Logs | 5 GB | 5 GB, +$0.50/GB |
| Cron monitors | 1 ("All Sentry plans include one cron monitor and one uptime monitor") | 1, +$0.78/monitor |
| Uptime monitors | 1 | 1, +$1.00 each |
| Custom dashboards | 10 | 20 |
| Seats | one user | unlimited |
| Retention | 30-day lookback | up to 90-day lookback |
| Alerting | issue alerts, "Alerts and notifications via email" | adds "API & third-party integrations" (Slack, Discord, etc.) and metric alerts |
| Seer | add-on "for Team and Business plans", $40/active contributor/mo, 14-day trial | same |
| Release health | included (sessions are not billed, any plan) | included |
| Spike protection | per-project, any plan; Billing/Owner can toggle | same |

Over quota: "Events and attachments that exceed your quota will not be accepted"; dropped, not billed. "The PAYG budget is only available on paid plans", so on Developer the rest of the month is dark. Spend notifications fire at 80% and 100% of reserved volume. Slack is not on Developer; alerts go by email only. New orgs get one 14-day Business trial, later one 14-day trial per product.

- https://sentry.io/pricing/
- https://docs.sentry.io/pricing/
- https://docs.sentry.io/pricing/quotas/
- https://docs.sentry.io/pricing/quotas/manage-cron-monitors/
- https://docs.sentry.io/pricing/quotas/spike-protection/
- https://docs.sentry.io/product/alerts/notifications/

## 2. Digests, throttling, and a low-noise setup

1. **Per-rule throttling** (Alerts > rule > "Perform these actions at most once every"; docs now call it "Throttling (previously called the action interval)"): "every trigger (default), 5 minutes, 10 minutes, 30 minutes, 60 minutes, 3 hours, 12 hours, 24 hours, 1 week, 30 days". It is per issue, per rule.
2. **Email digests** (Project Settings > Alerts, the "Digests" panel): minimum and maximum delivery interval sliders, defaults 5 and 30 minutes; the account-level "Minimum delivery interval" tops out at 60 minutes. Email only; Slack has no digest, which does not matter on Developer.
3. **Personal settings** (User Settings > Notifications): Alerts, Issue Workflow, Deploys, Weekly Reports (Saturdays, email), Spend, Spike Protection; each can be off or scoped per project.

One-person, free-plan configuration:
- Keep one rule per project: "A new issue is created", environment = production, throttle "once every 24 hours" (or 60 minutes while stabilizing). Delete the default "every event" rule.
- Add one regression rule: "The issue changes state from resolved to unresolved", same throttle.
- Project digests: minimum 30 min, maximum 60 min (the cap), so a bad release is one email an hour at worst.
- Personal: Weekly Reports on (it is the only free "trend" view), Issue Workflow off except Regressions, Deploys off.
- Set `environment` on every SDK so dev traffic never trips the production rule.

- https://docs.sentry.io/product/alerts/create-alerts/issue-alert-config/
- https://docs.sentry.io/product/notifications/notification-settings/
- https://blog.sentry.io/notification-digests/
- https://docs.sentry.io/product/alerts/notifications/

## 3. Release health

Gives crash-free sessions and users per release, adoption (sessions or active users over 24h), and release comparison. Sessions carry only release and environment tags. Cost: "We don't bill for release health sessions", and sessions bypass inbound filters, sampling and quota. Flutter: `enableAutoSessionTracking` defaults to `true`; a session ends after 30 s in background (`autoSessionTrackingInterval`); if disabled, "release health will not be available". The app already sets `options.release` and `options.environment` in all three `main_*.dart`, so this works today at zero quota.

- https://docs.sentry.io/product/releases/health/
- https://docs.sentry.io/platforms/dart/guides/flutter/configuration/releases/
- https://docs.sentry.io/platforms/dart/guides/flutter/configuration/options/

## 4. Profiling in Flutter

"Flutter Profiling is currently in Alpha and available only for iOS and macOS" (no Android, no web). It samples call stacks on sampled transactions ("shows you the most common code paths"); needs `tracesSampleRate` > 0 and `profilesSampleRate` relative to it. Billing is profile hours, PAYG only, not available on Developer: the SDK would send profiles that get dropped. Verdict: leave `profilesSampleRate = 0.0` (prod already gates it behind `config.enableSentryProfiling`) until there is a paid plan and a specific jank question.

- https://docs.sentry.io/platforms/dart/guides/flutter/profiling/
- https://docs.sentry.io/pricing/

## 5. Cron monitors, and what this repo actually schedules

A cron monitor is a check-in target (SDK, CLI, or HTTP `.../api/<project-id>/cron/<slug>/<public-key>/?status=in_progress|ok|error`) with `schedule`, `checkin_margin`, `max_runtime`, `timezone`, `failure_issue_threshold`. Sentry raises an issue on a missed, late, or failed check-in. Monitors upsert from the first check-in. Limit 6 check-ins/min per monitor environment. One free on any plan.

Scheduled work in the repo:

| Job | Mechanism | Schedule | Edge function? |
|---|---|---|---|
| `raw-retention-sweep` | pg_cron, `supabase/migrations/20260920180000_raw_retention_alert_wiring.sql` | `17 3 * * *` (03:17 UTC daily) | runs SQL `raw_retention_sweep_and_notify()`; only on alert does it `net.http_post` to `raw-retention-alert` (URL and token from Vault) |
| Refresh Feed Catalog | GitHub Action `.github/workflows/refresh-feed.yml` | `23 9 * * 1` | no, CLI + SQL against dev then prod |
| Sync Prod to Dev | GitHub Action `.github/workflows/sync-prod-to-dev.yml` | `0 15 * * 1` | no, `scripts/sync_prod_to_dev.js` |

`garmin-backfill` is not scheduled; it is invoked from `connect_training_controller.dart` on connect. No `ai-cost-alert` function or cron exists; `supabase/config.toml` has no cron entries; nothing in `supabase/` uses Supabase's dashboard cron. `garmin-push` is Garmin-initiated, not a schedule.

Recommendation: spend the one free monitor on prod `raw-retention-sweep`. It only emails on alert, so "no email" is indistinguishable from "cron died". Check in via `net.http_post` to the Sentry cron URL at start (`in_progress`) and end (`ok`/`error`) of `raw_retention_sweep_and_notify()`. The GitHub Actions already email on failure and need no monitor. Dev's sweep goes unmonitored on free.

- https://docs.sentry.io/product/crons/
- https://docs.sentry.io/product/crons/getting-started/http/
- https://docs.sentry.io/pricing/quotas/manage-cron-monitors/

## 6. Supabase's own error reporting vs in-function Sentry

Native: Dashboard > Functions > Invocations (request/response, duration) and Logs (boot/shutdown, `console.*`, "uncaught exceptions thrown by a function during execution" with stack); Logs Explorer SQL; MCP `query_logs`. Limits 10,000 chars/message, 100 events per function per 10 s. Retention: Free 1 day, Pro 7, Team 28, Enterprise 90. No alerting on function errors; the Metrics endpoint is Postgres-only and Reports are usage charts.

Supabase→Sentry log drain exists (also HTTP, OTLP, Datadog, Loki, S3, Axiom, Last9, Syslog) but ships *every* platform log as Sentry **logs**: "Ingesting Supabase logs as Sentry errors is not supported." Pro+ only, "$60 per drain per month, + $0.20 per million events, + $0.09 per GB egress", and it would eat the 5 GB log quota. Not worth it.

Comparison:

| | Supabase logs | `@sentry/deno` in the function |
|---|---|---|
| Catches | uncaught throws, console output, boot errors, every request | what you capture: uncaught (via `withSentry`), explicit `captureException`, handled-but-wrong paths you choose |
| Context | request id, region, status | stack, tags, user id, breadcrumbs, grouping, regression detection |
| Retention | 1 or 7 days | 30 days free |
| Alerting | none | issue alerts by email, throttled |
| Cost | included | counts against 5k errors |

Recommend: Supabase logs as the forensic layer, Sentry as the alert layer. The repo is already wired: `_shared/sentry.ts` wraps 31 functions with `withSentry` and no-ops without `SENTRY_DSN`. Supabase's guide uses `npm:@sentry/deno@^8`, `defaultIntegrations: false`, tags `SB_REGION`/`SB_EXECUTION_ID`, `await Sentry.flush(2000)`; the shared helper matches (esm.sh `@sentry/deno@8.53.0`, flush in wrapper). `Deno.serve` is not instrumented, so use `withScope` per request, not global scope.

- https://supabase.com/docs/guides/functions/logging
- https://supabase.com/docs/guides/platform/logs
- https://supabase.com/docs/guides/platform/metrics
- https://supabase.com/docs/guides/telemetry/log-drains
- https://supabase.com/pricing
- https://supabase.com/docs/guides/functions/examples/sentry-monitoring

## 7. Setup overhead for two edge-function Sentry projects

One project each for `edge-dev` and `edge-prod`:

1. Create project: UI, `POST /api/0/teams/{org}/{team}/projects/` (`name`, `platform`; scope `project:write`), or Sentry MCP (`create_project`, `create_team`, `create_dsn`, `list_dsns`; needs `project:write`/`team:write`). This session's `mcp__sentry__*` exposes only `authenticate` until signed in.
2. Copy the DSN (returned by `create_project`/`list_dsns`).
3. `supabase secrets set SENTRY_DSN=... SENTRY_ENVIRONMENT=edge-dev --project-ref vlmtsdzpnjnavdgytcmi`, same for `edge-prod`/`wvmvsodrvbkxfydabqed`. "Your functions read a new secret immediately, so you don't need to redeploy." Prod secret writes follow the playbook; ask first.
4. Add the two issue-alert rules from §2 per project, delete the default.
5. Smoke: hit a function with a bad payload, confirm the event lands, confirm `environment` tag.

Caveats: the 5k-error pool is org-wide, so a chatty edge bug can starve the Flutter project; set edge `tracesSampleRate` to 0 (now 0.1). Effort: ~30 min by API/MCP, under an hour by hand including alert rules; code is already done.

- https://docs.sentry.io/api/projects/create-a-new-project/
- https://github.com/getsentry/sentry-mcp
- https://supabase.com/docs/guides/functions/secrets
