# 22: Timestamps and startup telemetry

**Status:** in-progress (wave 2b, 2026-10-07)
**Labels:** fix, round:develop-2026-10, area:telemetry
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 29 (the backport ticket runs first, alone, because its Touches cross every area).
**Next:** `/testing-wave develop-2026-10` (fix wave)
**Model:** opus

**What to build:** Lee's rulings of 2026-10-07 (TRIAGE 01-004, 01-006, 08-009). One agent, working through the
list. Read `CLAUDE.md` (D9 silent paths, seam tests) and `docs/test/README.md` § Seam tests first. Line
numbers are from code at `f2e8576e`; re-read after 29 lands.

**Notification rule.** Item 3 touches `notification_service.dart` and the startup chain. CLAUDE.md says to
invoke the `notification-testing` skill first and read `ops/docs/messaging-relay-and-testing.md`. That skill
is missing on this branch (IMPROVEMENTS #101). Read the fact sheet if it exists, and read
`lib/shared/services/notification*.dart` end to end before changing anything there.

1. **`created_at` goes out in UTC (01-004).** These client writes send a local `DateTime` through
   `toIso8601String()`, which has no offset, so Postgres reads the wall clock as UTC (5 h early in CDT):
   - `public.users`: `UserProfile.toJson` (`user_preferences.dart:509-510`, `created_at` and `updated_at`),
     upserted at `user_repository.dart:141`, `:897`, `:930`; the reset-anonymous upsert
     (`user_repository.dart:697-698`); `auth_migration_service.dart` `'updated_at': DateTime.now()
     .toIso8601String()` in `_upsertOAuthUserFromAnonymousProfile` (~`:254`) and `:335`.
   - `public.daily_macro_targets`: `DailyMacroTargets.toJson` (`daily_macro_targets.dart:300-301`), upserted at
     `daily_macro_targets_repository.dart:270` and `:276`. Local values come from `DateTime.now()` (`:246`) or
     Drift epoch ints read back as local time (`daily_macro_targets_repository.dart:446`).
   - **Change:** send `.toUtc().toIso8601String()` at each site above, as `meal_log.dart:233` and
     `saved_meal.dart:134` already do. Other tables send naive times too (coach, feedback, food preferences,
     integrations, carb loading; grep `'created_at': .*toIso8601String()`). They are outside this ruling: list
     them in the ticket's closing note, do not change them.
   - **Why pass A was 10 h off (from code, unverified on device).** `UserProfile.toJson` sends `created_at` on
     every profile upload, not only the first. Once a wrong instant is on the server, the next download parses
     it (`user_preferences.dart:329`, `:416`), Drift keeps it as epoch, it comes back as local time, and the
     next upload sends it naive again: one more offset per round trip. Pass A went through two uploads. With
     UTC on the wire the value stops moving. Existing rows stay wrong: the ruling asks for no backfill.

2. **A dashboard transient that resolves under its threshold is a breadcrumb (01-006).**
   `DashboardTransientTelemetry` (`dashboard_transient_telemetry.dart:40-102`) sends a `Report.degraded`
   `DashboardTargetsAnomaly` when an episode opens ("Dashboard shown without targets", `:69-75`) and another
   when it closes ("Dashboard targets transient resolved", `:49-57`). After every signup that is two warning
   events for a 756-877 ms wait. No threshold exists in this file.
   - Add `transientThreshold`. Unverified number: no threshold is named in code or in the ruling. Use
     `PerformanceTelemetry.slowCeiling` (10 s, `performance_telemetry.dart:30`), the app's one bar for "a wait
     is an event", unless the lead brings a different number from Lee before the wave.
   - **Opening** with reason `computing` or `empty`: a breadcrumb only (keep the `PerformanceTelemetry.record`
     call at `:80-85`), and start a `Timer(transientThreshold)` for that episode. If the timer fires and the
     episode is still open, send the degraded event "Dashboard shown without targets" with `reason` and
     `open_ms`. Reason `error` keeps today's immediate event: a calculation error is a finding, not a wait.
   - **Closing**: under the threshold, a breadcrumb with `duration_ms` and cancel the timer. At or over it, the
     degraded "resolved" event as today, with `duration_ms`.
   - The once-per-process key (`_reportedShown`) and `debugReset` cover the timers too (cancel them). Rewrite
     the doc comment (`:13-23`): its "both stay events (ticket 11)" is superseded by this ruling.
   - A stuck dashboard still ships: the timer event goes out while it is stuck. If the app dies before the
     threshold, only the breadcrumb is lost, and nothing was wrong long enough to matter.

3. **The `deferred.notifications` timer leaves out the OS permission prompt (08-009).** The timer is
   `PerformanceTelemetry.measure` (`performance_telemetry.dart:43-68`), called by `_deferredStep`
   (`app_startup_service.dart:270-284`) for `'deferred.notifications'` (`:313-327`). Inside it,
   `NotificationService.initialize()` awaits `_initializeOneSignal()` (`notification_service.dart:202`), which
   awaits `OneSignal.Notifications.requestPermission(false)` (`:253`). On a fresh install that call puts up the
   iOS "Would Like to Send You Notifications" prompt and returns only when the athlete answers, so the 18 s
   offline launch was mostly the athlete. (The explicit `requestPermissions()` at `:692` is not in startup;
   the unawaited `_initializeOneSignal()` from `configureRemotePush` at `:88` runs outside the timer.)
   - `NotificationService` times the `requestPermission(false)` await with a `Stopwatch` and adds it to a
     static `permissionPromptWait` (reset by `debugReset` or its test hook). Write it down (D9): a
     `LaunchTrail.add('permission prompt wait <ms>ms granted=<bool>')` line next to the existing push-heal lines.
   - `PerformanceTelemetry.measure` and `_recordDuration` take an optional `Duration Function()? userWait`. The
     slow and ceiling checks (`:95`, `:105`) use `elapsed - userWait()`, floored at zero. The breadcrumb and
     span payload carry `duration_ms` (net), `user_wait_ms` and `wall_ms`, so nothing is hidden.
   - `_deferredStep` passes `userWait: () => NotificationService.permissionPromptWait` for
     `'deferred.notifications'` only. `slowThreshold`, `slowCeiling` and the other three reported operations
     (`deferred.revenuecat`, `dashboard.activities.background_sync`, `dashboard.integration_sync`) stay as they
     are. Ticket 17's retest on a lone simulator decides whether those three are real (ruling).
   - Unverified: whether OneSignal 5.5's `requestPermission(false)` returns at once when permission is already
     decided. If it does not, the excluded time is still visible as `user_wait_ms`.

**Findings:** 01-004, 01-006, 08-009.

**Decisions:** none on the page. Lee ruled in the terminal (TRIAGE 2026-10-07: 01-004, 01-006, 08-009).
Unverified, for the lead: the transient threshold number (item 2).

**Touches:** lib/features/auth/domain/user_preferences.dart, lib/features/auth/data/user_repository.dart,
lib/features/auth/application/auth_migration_service.dart,
lib/features/daily_macros/domain/daily_macro_targets.dart,
lib/features/macro_dashboard/application/dashboard_transient_telemetry.dart,
lib/shared/services/report/performance_telemetry.dart, lib/shared/services/notification_service.dart,
lib/features/app_startup/application/app_startup_service.dart,
test/features/auth/domain/user_profile_timestamps_test.dart (new),
test/features/daily_macros/daily_macro_targets_roundtrip_test.dart,
test/features/daily_macros/data/daily_macro_targets_upload_utc_test.dart (new),
test/features/macro_dashboard/application/dashboard_transient_telemetry_test.dart,
test/shared/services/report/performance_telemetry_test.dart,
pubspec.yaml (only if `fake_async` must be listed as a dev dependency for the timer tests).
No codegen: no Riverpod or Drift annotation changes.

**Overlaps:** 21 (`lib/features/auth/domain/user_preferences.dart`: `UserProfile.toJson`), 29 (backports cross
every area). 28 shares no file (it touches `launch_trail.dart` and `root_app_widget.dart`, not
`notification_service.dart`). Tickets 23, 24, 26, 27 were not written when this was cut: the lead checks
`app_startup_service.dart` and `notification_service.dart` against them.

- [ ] Seam test (`user_profile_timestamps_test.dart`): feed a server-shaped row (`created_at:
      '2026-10-07T11:11:03.123456+00:00'`, Postgres's microseconds and offset), save it locally, read it back,
      upload it twice through `UserRepository` with a fake Supabase that captures the upsert. Each sent
      `created_at` ends in `Z` and `isAtSameMomentAs` the original. Asserting the `Z` catches a naive string in
      any machine time zone.
- [ ] Same for `daily_macro_targets` (`daily_macro_targets_upload_utc_test.dart`), through the repository's
      save path, starting from a Drift epoch row; extend the round-trip test to check the wire string.
- [ ] `dashboard_transient_telemetry_test.dart` with `RecordingReport` and fake time: the observed sequence
      (computing, then targets at 876 ms) sends no degraded event; computing stuck past the threshold sends one
      event when the timer fires and one "resolved" event when it ends; reason `error` sends at once.
- [ ] `performance_telemetry_test.dart`: an 18 s `deferred.notifications` with 15 s of `userWait` sends no
      degraded event and its breadcrumb carries `user_wait_ms: 15000`; a 12 s step with no wait still sends one.
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest: ticket 30 (signup) reads `created_at` on `users` and `daily_macro_targets` against
      `email_confirmed_at`, and no `DashboardTargetsAnomaly` event follows a normal signup. Ticket 17's
      lone-simulator cold start: no `deferred.notifications` warning when the prompt is left up.
