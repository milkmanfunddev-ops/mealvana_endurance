# 54: Startup expected failures are recorded in Sentry, not held for analytics

**Status:** in-progress (wave 6, 2026-10-08) (round develop-2026-10, fix wave 6)
**Labels:** fix, round:develop-2026-10, area:telemetry
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing in code; runs in the fix wave after retest wave 5 (cut at the wave-4 close from ticket 41's question).
**Next:** `/testing-wave develop-2026-10` (fix wave after retest wave 5)
**Model:** opus

**What to build:** Ticket 41 (`013c608a`, `f1c17f11`, landed `98b15919`) turned expected failures into breadcrumbs plus one `expected_failure` analytics event per attempt (Lee's ruling of 2026-10-08, review queue 6). Three startup sites run before analytics consent is known: the version check (`version_check_service.dart`), the region lookup (`privacy_region_service.dart`) and the notification-answer note (`app_startup_service.dart`). Their counts are held in `ExpectedFailureCounts` (`report.dart`) and flushed through the consent-gated tracker after `app_opened`; with no consent, or a launch that never reaches analytics start, they are never sent, and the holder caps at 50. Lee, 2026-10-08, on that question: "we can send them to sentry but we needn't necessarily have any analytics."

So the startup sites record in Sentry and do not wait for analytics:

1. **Drop the hold for the startup sites.** `faultUnlessWeather` at those three sites stops queueing into `ExpectedFailureCounts`. If no other caller uses the holder afterwards, delete it and its tests; `trackExpectedFailure` keeps working for the in-session sites (auth, lesson video), which already have a tracker.
   ```
717:abstract final class ExpectedFailureCounts {
729:  static Future<void> attach(AnalyticsTracker? Function() sink) async {
742:  static void _hold(String area, String reason, Report? report) {
778:    ExpectedFailureCounts._hold(area, reason, report);
   ```
2. **Sentry carries the count.** A breadcrumb alone is not countable (it only rides on a later event). Record each startup weather failure as a Sentry metric counter, `expected_failure` with tags `area` and `reason`, through `Report` (a new `Report.count(name, tags)` that `SentryReport` implements with the SDK's metrics API and `NoopReport`/`RecordingReport` record). Verify first that the pinned `sentry_flutter` version exposes metrics; if it does not, fall back to a `warning`-level Sentry event with `fingerprint: ['expected_failure', area, reason]` so the three sites group into three issues whose event counts are the counts, and say so in the ticket. Either way, no `error_reported` analytics event.
3. The LaunchTrail line and the breadcrumb at each site stay (D9).
4. Ticket 41's seam tests for the three sites change from "held count" to "one Sentry count (or event) with the tags"; `report_test.dart` covers the new `Report.count`.

**Findings:** none (ticket 41's open question).

**Decisions:** Lee's words above. The in-session sites (auth outcomes, the lesson video) keep the analytics event: they run with consent known.

**Touches:** lib/shared/services/report/report.dart, lib/shared/services/report/sentry_report.dart (or wherever `SentryReport` lives; grep `class SentryReport`), lib/shared/services/version_check_service.dart, lib/shared/services/privacy/privacy_region_service.dart, lib/features/app_startup/application/app_startup_service.dart, test/shared/services/report/report_test.dart, test/new_sync/version_check_service_test.dart, test/privacy/privacy_region_service_test.dart, test/features/app_startup/notification_answer_breadcrumb_test.dart, test/helpers/fakes (the `RecordingReport` fake). About 10 files. No generated files.

**Overlaps:** none with 52 or 53. `app_startup_service.dart` is the startup chain: read it fully first; D9 at every branch.

No edge-function or schema change. Nothing to deploy.

- [x] Seam tests at the three sites: offline → one `expected_failure` count with `area` and `reason`, one breadcrumb, one LaunchTrail line, no event, no analytics call; a parse error still faults.
- [x] `report_test.dart`: `Report.count` on `SentryReport` reaches the SDK (or the fallback event with the fingerprint); `NoopReport` is silent.
- [x] `flutter analyze` clean on touched files.
- [ ] Retest: an offline cold start on a simulator shows the count (or the grouped warning) in dev Sentry within a minute, and no `error_reported`.

Next: /testing-wave develop-2026-10

## Fix notes

Fix wave 6, pass A, 2026-10-08. Code commit `cee2d94d` on `testing-wave/develop-2026-10/54` (base `876ca27e`).

**Sentry mechanism: metrics, not the fallback.** The pinned `sentry` / `sentry_flutter` 9.30.1 (pubspec.lock) has a metrics API: `Sentry.metrics.count(name, value, attributes:)`. `Sentry.init` installs it through `MetricsSetupIntegration`, and `enableMetrics` defaults to true; bootstrap does not turn it off. Counters go out as `trace_metric` envelope items, batched by the same telemetry processor as the structured logs. So no fingerprinted warning event was needed.

**What changed**
- `lib/shared/services/report/report.dart`: new `Report.count(name, {tags})`. `SentryReport.count` writes to the debug log and sends one counter (+1, tags as string attributes) through `Sentry.metrics`, which routes to the current hub the same way `Sentry.logger` does. If the SDK throws, `_captureFailed` records it. `NoopReport.count` does nothing. `trackExpectedFailure(null, …)` now calls `Report.count(expected_failure, {area, reason})` and returns; with a tracker it still sends the analytics event. `ExpectedFailureCounts` (the hold, its 50 cap, `attach`, `debugReset`) is deleted, because nothing else used it. The `faultUnlessWeather` doc comment states the rule ticket 55 depends on: with no tracker in hand, one Sentry count and no analytics hold.
- `lib/features/app_startup/application/app_startup_service.dart`: removed the `ExpectedFailureCounts.attach` call after `app_opened`. The no-profile branch of `_storeNotificationPermission` keeps its LaunchTrail line and `push` breadcrumb, and its count now goes to Sentry. Only the comment changed. No branch was added or removed, so D9 holds as before.
- `lib/shared/services/version_check_service.dart`, `lib/shared/services/privacy/privacy_region_service.dart`: comments only. These sites already pass no tracker, so they get the Sentry count. Their breadcrumbs and LaunchTrail lines are unchanged.
- `test/helpers/fakes/recording_report.dart`: records `count` and adds a `counts` getter.
- Tests: `report_test.dart` adds a `count` group: a `trace_metric` counter with `area`/`reason` attributes, no event, no `error_reported`, and the debug-log mirror. `NoopReport` emitting nothing now covers `count`. The old "held until analytics attaches" test became "no tracker → one Sentry counter". In `version_check_service_test.dart`, `privacy_region_service_test.dart` and `notification_answer_breadcrumb_test.dart`, offline gives one `expected_failure` count tagged area/reason, one breadcrumb, one LaunchTrail line, and no fault, degraded or note. The notification test also checks that analytics never sees `expected_failure`. A parse or malformed-body error still faults with no count.
- Source guard: removed the `trackExpectedFailure` sink-lookup allow-list entry, since that catch is gone. Added a reasoned entry for `SentryReport.count`'s SDK catch (`_captureFailed`, the same pattern as `note` promotion). `reportCalls` gets a comment instead of an entry: `report.count(` and `_report.count(` already match `report.` and `_report.`, and a bare `.count(` would also excuse Drift `.count()` calls.

**notification-testing skill:** it is not on this machine (IMPROVEMENTS #101/#123). I read `app_startup_service.dart` in full and the notification-answer path in the code. The only change on the push path is where the no-profile count goes. Arming, the ask and storage are untouched.

**Async paths**
- `Report.count` is synchronous, and the SDK captures the metric unawaited. If two run at once, that is two +1s, which is correct because Sentry sums them. Nothing holds state between calls, so a refresh or a disposed provider changes nothing: `ref.report` falls back to `SentryReport.global`.
- `_storeNotificationPermission` running twice (the ask plus a resume) sends two counts, one per dropped answer. That is what the count is for.
- `_initializeAnalytics` running twice (deferred startup plus post-consent) has one less await. Nothing is flushed, so there is nothing to double-send.

**Behaviour change for the lead:** the lesson video (`video_player_screen.dart`) passes a nullable `_analytics`. When that is null it used to be held, and now it is a Sentry counter, by the same rule. Auth sites always pass a tracker, so they are unchanged.

**Tests run** (no full suite, per the RUNBOOK)
- `report_test.dart`, `version_check_service_test.dart`, `privacy_region_service_test.dart`, `notification_answer_breadcrumb_test.dart`, `test/shared/source_guard/`: 84 passed.
- #116 sweep: all 148 test files under `test/` that name `Report` / `RecordingReport` / `NoopReport` / `SentryReport` / `trackExpectedFailure` / `faultUnlessWeather` / `noteExpected` / `ExpectedFailureCounts` / `AppStartupService` / `VersionCheckService` / `PrivacyRegionService` / `expectedFailureEvent`: 1423 passed, 0 failed.
- `flutter analyze` on the 4 lib files, the 5 touched test files and `test/shared/source_guard/`: no issues.

**Left for the lead**
- Retest box (unticked): an offline cold start on a simulator should show the `expected_failure` counter in dev Sentry (Explore → Metrics, grouped by `area`/`reason`) within a minute, with no `error_reported`. Counters flush with the telemetry batch, so allow the flush interval. If the dev Sentry org does not take trace metrics, the SDK drops them without a sound. That is the moment to switch `SentryReport.count` to the warning-event fallback the ticket names, a change inside one method.

