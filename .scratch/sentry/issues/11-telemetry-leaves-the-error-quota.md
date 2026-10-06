# 11: Telemetry leaves the error quota

**What to build:** iOS MetricKit metric payloads arrive as structured logs instead of info events; MetricKit diagnostic payloads stay events. Slow-operation thresholds in the performance telemetry record span measurements on the existing startup and dashboard transactions instead of error events, and one warning event remains for a step over a 10-second ceiling. A Sentry dashboard widget shows p95 per startup step. The dashboard-targets and plan-generation anomaly messages stay as warning events.

**Blocked by:** 01 Report service exists

**Status:** done

- [x] A fresh launch of a dev build produces no `MetricKit metric payload` event; the data is visible under Logs (unit tests only; no device run — see Sites)
- [x] A MetricKit diagnostic payload still produces an event tagged `metrickit`
- [x] A slow startup step appears as a measurement on the startup transaction; no `Slow operation:` event is produced below the ceiling; one warning event is produced above it
- [x] A dashboard named for startup performance exists in the org with a p95-per-step widget
- [x] Tests cover the ceiling boundary and the span emission through the transport

## Sites

Verified by unit tests only; no device or simulator was run, so "fresh launch" is the
test's claim, not an observed one. Device check owed.

- `ios/Runner/MetricKitReporter.swift` — Rewired — no longer imports or calls the Sentry SDK; forwards each payload's JSON over method channel `com.milkman.mealvanaendurance/metrickit` (`metric` / `diagnostic`), buffering until Dart calls `ready` so the launch-time daily payload is not lost.
- `ios/Runner/AppDelegate.swift:144` — Rewired — `register(messenger:)` with the FlutterViewController's binary messenger.
- `lib/shared/services/report/metrickit_relay.dart` (new) — metric payload → `Report.info('MetricKit metric payload', area: 'metrickit', data: <flattened payload, cap 120 attributes>)`, a structured log, no event; diagnostic payload → `Report.degraded(MetricKitDiagnostic, tags: {metrickit: diagnostic, diagnostic_kind}, extra: {diagnostic_kinds, payload}, fingerprint: [metrickit-diagnostic, kinds...])`, a warning event tagged `metrickit`.
  - `:43 on MissingPluginException` — Reasoned — non-iOS host, nothing will arrive.
  - `:104 on FormatException` — Reasoned — the catch is the parse; raw payload forwarded under `raw`.
- `lib/shared/core/bootstrap/bootstrap.dart:231` — starts `MetricKitRelay` on iOS before `runApp` (handler installed before the native flush).
- `lib/shared/core/bootstrap/sentry_event_filter.dart:52` — comment updated; `isDiagnosticEvent` unchanged (still keyed on the `metrickit` tag).
- `lib/shared/services/performance_telemetry.dart` → moved to `lib/shared/services/report/performance_telemetry.dart` (7 import paths updated: daily_macro_service, daily_macros_controller, app_startup_service, app_startup_provider, activities_controller, app_database, guarded_navigation).
  - `recordDuration` / `measure` — span: `perf.step` child of the scope-bound transaction (startup route / dashboard route) with `description` = step, `duration_ms` data and a `setMeasurement(<step>, ms)`; a standalone one-span transaction named for the step when nothing is bound. `measure` opens the span before the work (the SDK refuses a child that starts before its parent); `recordDuration` back-dates and clamps to the parent's start.
  - Below `slowCeiling` (10 s): breadcrumb (warning at ≥ 2 s) + span, no event. At/over: one `Report.degraded(SlowOperation)` per step per process, `area: performance`, fingerprint `[slow-operation, <step>]`.
  - `recordDatabaseReset` — Degraded — was a direct `captureMessage` warning; now `Report.degraded(DatabaseReset)`, same level, fingerprint `[database-reset, reason]`.
  - `record(level: SentryLevel)` → `record(warning: bool)` so callers never name an SDK type.
  - `:_startSpan catch (_)`, `:_finishSpan catch (_)` — Reasoned — span bookkeeping inside the Report layer.
- `lib/features/macro_dashboard/application/dashboard_transient_telemetry.dart` — Degraded — both anomaly messages stay warning events via `Report.degraded(DashboardTargetsAnomaly)`, `area: macro_dashboard`, fingerprint `[dashboard-targets, <message>]`; `sentry_flutter` import gone; `debugCaptureOverride` replaced by `reportOverride` (RecordingReport).
- `test/shared/source_guard/allow_list.md` — deleted the two `sentryImport` baseline lines (dashboard_transient_telemetry, performance_telemetry); added 4 `reasoned` lines for the catches above. There was no `unreportedCatch` baseline line for `performance_telemetry.dart` to delete.

Tests: `test/shared/services/report/performance_telemetry_test.dart` (9.999 s → span + measurement, no event; 10 s → one warning event per step with fingerprint; child span on a bound transaction), `test/shared/services/report/metrickit_relay_test.dart` (RecordingReport + SDK transport: metric = one log, no event; diagnostic = one warning event tagged `metrickit`; channel `ready` + native→Dart delivery), `test/features/macro_dashboard/application/dashboard_transient_telemetry_test.dart` rewritten on RecordingReport.

## Dashboard

`Startup performance` — https://milkman-24.sentry.io/dashboard/10329307/ (org `milkman-24`, all projects, created
2026-10-06 via `POST /api/0/organizations/milkman-24/dashboards/`, HTTP 201; the Developer plan accepted it).
Widgets:
1. `p95 per startup step` — spans table: `span.description`, `p95(span.duration)`, `count(span.duration)` where `span.op:perf.step`, ordered by p95.
2. `p95 per step over time` — spans line chart, same query, top 10 steps, 1 h interval.
3. `Steps over the 10 s ceiling (warning events)` — error-events table: `operation`, `count()`, `count_unique(user)` where `message:"Slow operation:*" severity:degraded`.
Empty until a build carrying this commit runs; p95 reads from span metrics, so the dashboard needs
`tracesSampleRate` > 0 (dev 1.0, prod 0.1 today).
