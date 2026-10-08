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

- [ ] Seam tests at the three sites: offline → one `expected_failure` count with `area` and `reason`, one breadcrumb, one LaunchTrail line, no event, no analytics call; a parse error still faults.
- [ ] `report_test.dart`: `Report.count` on `SentryReport` reaches the SDK (or the fallback event with the fingerprint); `NoopReport` is silent.
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest: an offline cold start on a simulator shows the count (or the grouped warning) in dev Sentry within a minute, and no `error_reported`.

Next: /testing-wave develop-2026-10
