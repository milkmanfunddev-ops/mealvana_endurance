# Sentry dashboard state, read 2026-10-05 via Sentry MCP (org milkman-24)

## Projects and DSNs
- mealvana-endurance (prod, id 4509882394083328), one DSN "Default" 00d9cb3e…
- mealvana-endurance-dev (dev, id 4510121638166528), one DSN "Default" 40b04814…
- Environments seen in 90 days: development, production. NO edge-dev / edge-prod environment has ever reported.
  => edge functions have never sent an event despite SENTRY_DSN/SENTRY_ENVIRONMENT secrets being set on both Supabase projects.
- 17 events tagged environment=development landed in the PROD project in 30 days: dev builds falling to the hardcoded prod DSN fallback in AppConfig.

## Volume, last 30 days (free quota 5,000 errors org-wide)
| project | env | events |
|---|---|---|
| mealvana-endurance-dev | development | 1,346 |
| mealvana-endurance | production | 958 |
| mealvana-endurance | development | 17 |
Prod by level: warning 372, info 298 (MetricKit metric payloads: one issue, 296 events, 29 users), error 280, fatal 8 (unhandled: SIGSEGV x3, SIGBUS, WatchdogTermination x3, OUTLINED_FUNCTION).
"Slow operation: …" captureMessage events (performance_telemetry) account for ~20 prod issues and ~300 events; these spend error quota on timing data.

## Alert rules (issue alerts)
- 2569558 "Send a notification for high priority issues" (prod, default rule, 30 min frequency, no env filter, last fired 2026-10-05)
- 2679920 same, dev project (last fired 2026-10-01)
- 5648553 "Send a notification when pull requests are ready" (2026-09-18, never fired)
- No regression rule, no metric alerts, no cron monitors, no uptime monitors.

## Prod unresolved issues, 30d: 60. Themes
1. Riverpod lifecycle (UnmountedRefException x8 issues incl CP 93 events/19 users allEventsProvider; StateError userIdProvider disposed; FlutterError "modify provider while building" x3)
2. Edge gateway 502/504 SentryHttpClientError (B5 57 events, AA, AB, C1, C4, C3, C0, BM) — mostly functions_client.invoke / connected_apps_row
3. Auth: OAuthAccountNotFoundException (CE 17, CZ, CQ) [expected business case]; webAuthenticationOptions Android Apple sign-in (A6 28 events, BY) [real bug]; Google sign_in_failed CF; AuthApiException Invalid API key CH; Account creation failed CG; refresh-token ClientException CX/CW
4. RLS 42501 integrations insert (3W, 59 events, 3 users, from welcome.get_started) [real bug]
5. Native crashes: SIGSEGV BP, SIGBUS C2, WatchdogTermination B7, OUTLINED_FUNCTION CR
6. Telemetry-as-issues: MetricKit AN/CD, Slow operation x20, Dashboard shown without targets C6, targets transient resolved C8, plan generation anomaly B9, Local database reset D2/BD, daily macro remote save failed BG
7. TrainingPeaks writeback 400 (CY, C7)
8. TypeError null check food_prefs.likes_dislikes_row (CC)

## Dev unresolved, 30d: 100+ (list capped). Extra themes beyond prod: RenderFlex overflows (5S coach-portal, 5H, 5G 20550px, 7W), Duplicate keys (9Y/9Z), N+1 Query (88/89/97), RevenueCat NETWORK_ERROR (8M etc, simulator), Test Store simulated purchase error 9H, qa-seed uuid upload failure 82, users RLS 42501 (DEV-4, 36 events), raw_retention_sweep_stale 9B, AI cost messages 8Z/8Y, VanaUnauthenticated 90/91, ProRequired 9C, CodeRedeemFailure 9A, VideoPlayerController disposed 9R, navigator assertion 9G/9F, deactivated widget ancestor 81.
