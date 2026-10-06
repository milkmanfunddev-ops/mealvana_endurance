# Sentry is the one error service

**Labels:** ready-for-agent
**Branch:** `sentry` (off `develop`, 2026-10-05). Lands on `develop` by PR, next release train.
**Grill record:** this conversation (Lee, 2026-10-05). Research in `research/` beside this file.
**Glossary:** `CONTEXT.md` § Error reporting (Report, Fault, Degraded, Note, Expected failure, Silent path).

## Problem Statement

Lee cannot see what breaks. The app has Sentry under it, but about 1,100 catch blocks exist and
only about 110 reach Sentry; 374 write to a logger that goes to the console and an in-app debug
screen and nowhere else, 90 are empty, 52 only print. Edge functions have a Sentry wrapper and DSN
secrets, yet no edge event has ever arrived in 90 days. A silent `return` on an empty OneSignal id
disabled push for every fresh 1.29.0 install and hid for two days; that episode produced rule D9.
Meanwhile a third of the prod error quota is spent on telemetry that is not an error (MetricKit
metric payloads, "slow operation" timings), the SDK is 24 minor versions behind, alerts are the
two Sentry defaults, and 60 prod issues sit unresolved.

## Solution

One service, `Report`, through which every error, warning and silent-path note leaves the app and
every edge function. Errors fail silently for the athlete and loudly for Lee. A severity ladder
(Fault, Degraded, Note) and an expected-failure allow-list keep the signal clean. A repo test makes
silence a decision that needs a written reason. The SDK, the bootstrap, the Sentry project
settings and the alert rules are brought to current best practice on the free plan. Then every
open issue in both projects is fixed, as its own ticket, against the new visibility.

## User Stories

1. As Lee, I want every caught exception in the app to reach Sentry, so that nothing fails without my knowing.
2. As Lee, I want every caught exception in every edge function to reach Sentry, so that server failures are as visible as app failures.
3. As Lee, I want one API to call when code hits an error, so that no call site has to choose between a logger and a reporter.
4. As Lee, I want the old logger, debug logger and Sentry wrapper gone, so that there is no dead or duplicate service left to drift.
5. As Lee, I want a Fault (unexpected failure) to arrive as a Sentry error, so that it shows in alerts and triage.
6. As Lee, I want a Degraded condition (offline, timeout, expired session, user-cancelled sign-in) to arrive as a warning that never alerts, so that I can count it without it drowning Faults.
7. As Lee, I want a Note (a silent path took a branch) to arrive as a breadcrumb on the next event, so that a crash carries the trail that led to it.
8. As Lee, I want Notes in startup, push, payments and sync promoted to warning events, so that rule D9 is satisfied in the four paths it was written for.
9. As Lee, I want an allow-list of expected exception types that `Report` downgrades on its own, so that call sites never have to remember what is noise.
10. As Lee, I want test-only exceptions dropped, so that the suite never pollutes a project.
11. As an athlete, I want the app to keep working when something fails in the background, so that an error never becomes a broken screen.
12. As Lee, I want every provider failure, including those caught by `AsyncValue.guard`, reported once, so that the Riverpod net is complete and does not double-count.
13. As Lee, I want a `ProviderException` wrapping an already-reported error to be unwrapped or skipped, so that one failure is one issue.
14. As Lee, I want each Riverpod build retry recorded as a breadcrumb, so that a flaky provider that recovers still shows up as a trail.
15. As Lee, I want a crash to arrive marked unhandled with the Flutter mechanism, so that Sentry groups and prioritises it as a crash.
16. As Lee, I want one bootstrap for all four entry points, so that dev, prod and web cannot drift apart in how they report.
17. As Lee, I want dev builds never to fall back to the prod DSN, so that dev noise never lands in the prod project.
18. As Lee, I want each event to carry the Supabase user id and role, so that I can find an athlete's errors from their id and cross-reference Mixpanel.
19. As an athlete, I want no email or personal text in error reports, so that my privacy is kept.
20. As Lee, I want the expected-failure patterns sent as warnings rather than dropped, so that I can see how often athletes are offline or failing login.
21. As Lee, I want direct SDK calls banned outside the service, so that the Mixpanel fan-out and the ladder are never bypassed.
22. As Lee, I want Mixpanel to receive one `error_reported` event with severity, area and exception type, so that I can funnel sessions with a Fault.
23. As Lee, I want logger info and debug lines to arrive as Sentry structured logs, so that the console story of a session is readable next to its errors.
24. As Lee, I want MetricKit metric payloads as logs and MetricKit diagnostics as events, so that iOS health data stops spending error quota.
25. As Lee, I want slow-operation timings recorded as spans with a hard-ceiling warning, so that I still see slow steps without spending error quota on them.
26. As Lee, I want a Sentry dashboard widget of p95 per startup step, so that slow steps stay visible after they leave the issue list.
27. As Lee, I want the SDK on the latest stable 9.x, so that I have the current integrations and fixes without the 10.0 breaking changes.
28. As Lee, I want Supabase client breadcrumbs and trace propagation to edge functions, so that an app error shows the PostgREST calls before it and links to the edge log.
29. As Lee, I want each edge request to run in its own isolation scope, so that one request's tags never leak onto another's event.
30. As Lee, I want the shared edge response helpers to capture to Sentry themselves, so that most handlers are covered without being edited.
31. As Lee, I want ensure-credits and revenuecat-webhook wrapped like every other function, so that payments are not the one blind spot.
32. As Lee, I want a Deno test proving every function is wrapped and every catch reports, so that edge coverage cannot regress.
33. As Lee, I want a Flutter test that fails on any unreported catch in the app, so that the next wave cannot reintroduce silence.
34. As Lee, I want deliberate silent catches recorded in an allow-list with a one-line reason, so that silence is a decision, not a default.
35. As Lee, I want a lint that bans `print` and `debugPrint` inside catch blocks, so that the console is never the only witness.
36. As Lee, I want to stay on the free plan, so that the answer to too many errors is fewer errors, not a bigger bill.
37. As Lee, I want dev at 100% sampling with a per-project quota cap, so that waves see every error but can never starve prod of its share of the pool.
38. As Lee, I want spike protection armed on both projects, so that one bad build cannot drain the month.
39. As Lee, I want session replay off and on-error replay prod-only at the existing per-install cohort, so that the 50 free replays buy the first 50 real crashes.
40. As Lee, I want tracing at 10% in prod, 100% in dev and 0 on edge, so that performance data costs nothing I care about.
41. As Lee, I want one new-issue rule and one regression rule per project, throttled to once a day per issue, with email digests, so that I hear about new problems once and not 50 times.
42. As Lee, I want alert rules filtered to the production environment, so that dev noise never pages me.
43. As Lee, I want the weekly report for dev, so that I see the shape of dev noise without alerts.
44. As Lee, I want the unused pull-request alert rule deleted, so that the alert list is only what fires.
45. As Lee, I want one cron monitor on the nightly retention sweep, so that "no alert email" is distinguishable from "the cron died".
46. As Lee, I want release health visible (crash-free sessions and users per release), so that I can tell a bad release from a bad day.
47. As Lee, I want iOS symbols, Android mappings and web source maps uploaded in the release workflows only, so that prod stacks read as code without spending Codemagic minutes on dev cuts.
48. As Lee, I want each event tagged with the Shorebird patch number, so that a patched release is told apart from the base build.
49. As Lee, I want a dev-only debug-screen button that fires one of each class, so that any future wave can prove the pipeline end to end on a device.
50. As Lee, I want every open prod issue fixed as a ticket of its own, so that the backlog reaches zero against the new visibility.
51. As Lee, I want every open dev issue that is an app bug fixed likewise, so that dev stops being a graveyard.
52. As Lee, I want QA-seed data failures routed to the review queue, so that they reach the QA repo instead of becoming app tickets.
53. As Lee, I want the Sentry integration doc rewritten for the new service, so that the next agent reads one truth.
54. As Lee, I want LaunchTrail and Wiredash left untouched, so that this pass changes error reporting and nothing beside it.

## Implementation Decisions

### The service

- One class, `Report`, in the shared services layer, replaces `SentryReporter`, `AppLogger`
  (and `PrettyAppLogger`), `DebugLogger` and the in-memory `DebugLogStorage` as separate things.
  The debug screen keeps its log view, fed by `Report`.
- Public API, severity-first: `fault(error, {stackTrace, area, tags, extra})`,
  `degraded(...)`, `note(message, {area, data})`, `info(message)`, `debug(message)`, plus
  `setUser(id, role)`, `clearUser()`, `breadcrumb(...)`. The existing typed helpers
  (`reportCriticalError`, `reportDatabaseError`, `reportNetworkError`, `captureMessage`) and the
  logger's `error`, `warning`, `info`, `debug` remain as thin aliases during the sweep and are
  deleted when the last caller is moved; the sweep ends with no alias left.
- Mapping: Fault to Sentry `error`; Degraded to `warning`; Note to breadcrumb, promoted to a
  `warning` event when `area` is one of startup, push, payments, sync; info and debug to Sentry
  structured logs (`Sentry.logger`) and to the console in debug builds.
- Expected-failure allow-list: a single list of exception types and message patterns that
  `fault` downgrades to Degraded automatically (socket, timeout, handshake, cancelled sign-in,
  invalid credentials, expired session, user-cancelled purchase, `OAuthAccountNotFoundException`,
  RevenueCat network errors). The old `isSentryNoise` drop list becomes this list; only
  test-only patterns (`TestFailure`) are dropped.
- Mixpanel fan-out: every Fault and Degraded also sends one `error_reported` event with
  `severity`, `area`, `exception_type`, `sentry_event_id`. No message text.
- A `NoopReport` for tests and consent-off builds keeps the same interface.
- Provided through the existing external-deps provider; the separate logger and Sentry providers
  go away.

### Riverpod

- The provider observer stays as the universal net (it already fires for `AsyncValue.guard`
  errors and `build` throws). Two changes: a `ProviderException` is unwrapped and reported with a
  `wrapped` tag only if its inner error has not been reported, otherwise skipped; and a global
  retry callback on the root scope records a breadcrumb per attempt and delegates to the default.
- Deduplication key: provider name plus exception type plus message, within one session.
- No guard wrapper. `AsyncValue.guard` stays as it is at all 108 sites.

### Bootstrap

- One `bootstrap(flavor)` function replaces the copied init in the four entry points. It uses the
  documented shape: `SentryFlutter.init(options, appRunner: () => runApp(...))`, no manual
  `FlutterError.onError`, no manual `PlatformDispatcher.onError`, no `runZonedGuarded`. The
  SDK's own integrations tag crashes unhandled with the Flutter mechanism.
- Per-flavor options come from one table keyed by flavor: DSN, environment, traces rate, replay
  rates, debug flag. The hardcoded prod DSN fallback is removed; a missing DSN in dev disables
  Sentry with a Fault logged to console rather than reporting to prod.
- Web uses the same function with the web flavor; the three features it was missing (app-hang
  tracking off, breadcrumb filter, cohort replay) follow the table.
- Release stays `mealvana_endurance@<version>+<build>`, dist stays the build number, plus a
  `shorebird_patch` tag read at startup.
- User context: Supabase user id as the Sentry user id, `role` tag (athlete or coach),
  `device_id` tag. No email, `sendDefaultPii` off, replay masks text and images.

### SDK and integrations

- `sentry_flutter`, `sentry_drift` to the latest stable 9.x (9.30.1 at research time;
  10.0 stays out until it is stable and the toolchain meets its floors). `sentry_dart_plugin`
  to its latest 3.x.
- Add `sentry_supabase` so every PostgREST call is a breadcrumb and span; enable trace
  propagation so edge logs carry the app's trace id.
- `SentryNavigatorObserver` stays on the router; display tracking on for time-to-full-display.
- Direct SDK imports are allowed only in the service and the bootstrap. A lint rule enforces it.

### Telemetry that is not an error

- MetricKit: diagnostic payloads stay events (level info, tagged); metric payloads become
  structured logs.
- Slow-operation thresholds in the performance telemetry become span measurements on the
  existing startup and dashboard transactions. One warning event remains for any step over a
  hard ceiling of 10 seconds. A Sentry dashboard widget shows p95 per step.
- The dashboard-targets and plan-generation anomaly messages stay as events at warning level;
  they are real findings.

### Edge functions

- Same two Sentry projects; environment `edge-dev` and `edge-prod` from the Supabase secret;
  tag `component:edge_function`. `tracesSampleRate` 0.
- `@sentry/deno` stays on the 8.x line (the hosted runtime is Deno 2.1) at its latest 8.x.
- The wrapper runs each request under `withIsolationScope`, tags function name and method, and
  flushes before returning. The shared `serverError()` captures the error it is given;
  `errorResponse()` captures when passed an error object or a 5xx status, and breadcrumbs a 4xx
  with no error. Remaining raw `console.error` catches get an explicit capture or are routed
  through the helpers. ensure-credits and revenuecat-webhook are wrapped.
- First task of the edge ticket: prove the pipeline with a deliberate throw, since no edge event
  has ever arrived. Check the DSN secret value, the flush, and whether the runtime blocks the
  outbound call.

### Enforcement

- A Flutter test scans `lib/` and fails when a catch block neither rethrows, nor calls `Report`,
  nor appears in an allow-list file beside the test, where each entry carries a reason. The same
  test fails on a `sentry` import outside the two permitted locations and on `print` or
  `debugPrint` inside a catch.
- A Deno test scans `supabase/functions/*/index.ts` for the wrapper and runs each handler with a
  fake Sentry client against a request that forces an error, asserting a capture.

### Sentry project settings and alerts (done through the Sentry API or MCP in the build)

- Both projects: spike protection on; dev project quota cap 2,000 events per month; inbound
  filters for browser extensions and legacy browsers on for web.
- Alert rules per project: "New issue" and "Regression", environment production, actions
  email, frequency once per 24 hours per issue. Project digests at 30 minutes minimum, 60
  maximum. The two default rules are replaced; the pull-request rule is deleted. Dev project: the
  weekly report only.
- One cron monitor, `raw-retention-sweep`, schedule `17 3 * * *`, checked in from the sweep's
  edge function with a grace period of 30 minutes.
- Release health: nothing to enable; confirm sessions appear per release after the SDK bump.
- Symbol upload: the existing Codemagic step runs only in the release workflows and after a
  Shorebird patch; the plugin config gains the dev project so dev symbols stop landing in prod.

### Verification seam on device

- The debug screen, behind the existing admin gate, gets three buttons: throw a Fault, raise a
  Degraded, record a Note then throw. Acceptance: all three appear in the dev project within a
  minute with the right level, the user id, the breadcrumb trail, no replay, and the Mixpanel
  `error_reported` event. A fourth button calls an edge function with a bad payload; acceptance
  is one event in environment `edge-dev`.

### Backlog triage (tickets after the reporting tickets)

One ticket per theme, each listing its issue ids, each closing its issues in Sentry when fixed:

1. RLS 42501 on `integrations` insert from the welcome screen (59 events).
2. Android Apple sign-in `webAuthenticationOptions` (A6, BY).
3. Riverpod lifecycle: `UnmountedRefException` across `allEventsProvider`,
   `settingsControllerProvider`, `eventDetailProvider`, `macroDashboardDayProvider` and the dev
   set; `userIdProvider` disposed during loading; provider modified while building (CM, CJ, C5).
   Fix the pattern with `ref.mounted` checks after async gaps and the top offenders by hand.
4. Edge gateway 502 and 504 via `functions_client.invoke` and the connected-apps row (B5, AA,
   AB, C1, C4, C3, C0, BM): find the function, cold start or timeout, and fix or classify.
5. Auth: refresh-token connection aborts (CX, CW), Google `sign_in_failed` (CF), invalid API key
   (CH), account creation failed (CG), `OAuthAccountNotFoundException` reclassified as Degraded.
6. Native crashes (BP, C2, B7, CR): blocked on symbol upload; then read and fix.
7. TrainingPeaks writeback 400 (CY, C7).
8. Null check in the food-prefs likes row (CC).
9. Telemetry issues resolved by this spec's reclassification (AN, CD, the slow-operation set,
   C6, C8, B9, D2, BD, BG): closed once the new code ships.
10. Dev-only: RenderFlex overflows (5S, 5H, 5G, 7W), duplicate keys (9Y, 9Z), N+1 queries
    (88, 89, 97), `VideoPlayerController` after dispose (9R), navigator assertions (9G, 9F),
    deactivated ancestor (81), Vana unauthenticated and pro-required reclassified as Degraded.
11. QA-seed failures (DEV-4 users RLS, DEV-82 qa-seed uuid): review queue entry for the QA repo,
    not an app ticket.

## Testing Decisions

A good test drives the real object through its public API and asserts what leaves it, never how
it got there. Four seams, confirmed by Lee:

1. **Report service seam.** Tests construct the real `Report` with the Sentry SDK's in-memory
   transport swapped in and a fake analytics tracker, then assert the envelope: level, tags,
   user, breadcrumbs, allow-list downgrades, Note promotion by area, `ProviderException`
   unwrapping, retry breadcrumbs, the Mixpanel event, and that `NoopReport` emits nothing.
   Prior art: the sync tests in `test/new_sync/` already inject a no-op reporter; the SDK's
   transport injection is its documented testing hook.
2. **Source guard.** One Flutter test walks `lib/` and fails on unreported catches, forbidden
   imports and prints in catches, with the allow-list beside it. Prior art: the feature-survey
   removal test and the macro-dashboard gestures test already scan source.
3. **Edge seam.** One Deno test runs every function handler through the shared wrapper with a
   fake Sentry client and an error-forcing request, asserting one capture under its own scope;
   plus a scan that every `index.ts` uses the wrapper. Prior art: the garmin helper tests under
   `_shared`.
4. **Device check.** The debug-screen buttons against the dev project, by hand, recorded in the
   ticket with the event ids. This is the acceptance test for the feature as a whole.

Per-site tests at individual catches are not written; the guard test and the service seam cover
them. Controller write paths keep their existing seam tests.

## Out of Scope

- Upgrading to the Team plan, Slack alerts, metric alerts, Seer.
- Sentry 10.x.
- Profiling (alpha, iOS-only, paid), the Sentry feedback widget (Wiredash stays), uptime
  monitors.
- Separate Sentry projects for edge functions.
- Any change to LaunchTrail, Wiredash, or the notification path beyond reporting.
- Non-error analytics: Mixpanel events other than `error_reported` are untouched.
- Supabase log drains.
- A Shorebird patch carrying this work; it rides the next release train.

## Further Notes

- Free-plan numbers at research time: 5,000 errors, 5 million spans, 50 replays, 5 GB logs, one
  cron and one uptime monitor, 30-day retention, email alerts only. Last 30 days used 2,321
  errors across both projects, of which about 600 were telemetry this spec moves out of the
  error quota.
- 17 events tagged `development` sit in the prod project: the fallback-DSN bug this spec removes.
- The dev project's volume will rise once the 374 logger-only catches start reporting. The
  2,000 cap on dev and the triage tickets are the two answers; if dev still hits the cap, lower
  dev `sampleRate` before anything else.
- Rule D9 in `CLAUDE.md` is the standing rule this spec implements; the glossary terms Note and
  Silent path are its vocabulary.
- CONTEXT.md on this branch was copied from `mealplanning` and extended; expect an add/add
  merge when both reach `develop`, resolved by keeping both sections.
