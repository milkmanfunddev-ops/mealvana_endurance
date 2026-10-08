# 70: device_id on plan, activity and reminder analytics events

**Status:** in-progress (wave 6, 2026-10-08) (round develop-2026-10, fix wave 6)
**Labels:** fix, round:develop-2026-10, area:analytics
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 60 (it adds `deviceInfoServiceProvider.deviceId` to the eight integration events; this ticket follows the same pattern). Runs after 60 merges.
**Next:** `/testing-wave develop-2026-10` (fix wave 6)
**Model:** opus

**What to build:** Lee (2026-10-08, ticket 60's question): the plan and activity analytics events that send the user id as `device_id`, and the reminder events that send `'unknown'`, carry the real device id. Grep `device_id` across `lib/` and list every event and its current value in Touches before changing anything. The reminder events live on the notification path: CLAUDE.md's notification rule applies (the `notification-testing` skill and `ops/docs/messaging-relay-and-testing.md` are not on this machine; read `notification_service.dart` and the reminder scheduling code first and say so in the fix notes). Ticket 104 (`user_registered`) and ticket 60 are the pattern: `deviceInfoServiceProvider.deviceId`, read before any `await`.

**Touches:** every file that tracks one of those events (filled in by the agent from the grep, listed here before the first edit), `test/` fakes that assert the `device_id` property.

**Site list (agent, from `grep -rn "device_id\|deviceId" lib/`, before the first edit; line numbers at base `292b3813`):**

| # | File:line | Event | Value sent today |
|---|---|---|---|
| 1 | `lib/features/nutrition_plan/presentation/providers/macro_targets_controller.dart:589` | `plan_generation_started` (running) | user id (`user?.id ?? 'unknown'`) |
| 2 | same `:768` | `plan_generation_failed` (running) | user id, or `'unknown'` if the failure came before the user read |
| 3 | same `:819` | `plan_generation_started` (cycling) | user id |
| 4 | same `:1019` | `plan_generation_failed` (cycling) | user id / `'unknown'` |
| 5 | same `:1114` | `plan_generation_started` (swimming) | user id |
| 6 | same `:1299` | `plan_generation_failed` (swimming) | user id / `'unknown'` |
| 7 | same `:1352` | `plan_generation_started` (brick) | user id |
| 8 | same `:1570` | `plan_generation_failed` (brick) | user id / `'unknown'` |
| 9 | same `:2345` (via `_trackPinDecisions`, called at `:2030`) | `plan_used_pin` | `userProfile?.id ?? 'unknown'` |
| 10 | same `:2360` | `plan_pin_fallthrough` | `userProfile?.id ?? 'unknown'` |
| 11 | `lib/features/nutrition_plan/application/macro_generation_service.dart:109` | `plan_generated` (running) | `deviceId` param = user id |
| 12 | same `:187` | `plan_generated` (cycling) | user id |
| 13 | same `:261` | `plan_generated` (swimming) | user id |
| 14 | `lib/features/nutrition_plan/application/brick_macro_service.dart:179` | `plan_generated` (brick) | user id |
| 15 | `lib/features/activities/presentation/widgets/activity_card.dart:302` | `activity_viewed` | `activity.userId` |
| 16 | `lib/shared/services/notification_service.dart:812` | `reminder_clicked` (typed `reminder:` tap) | `'unknown'` |
| 17 | same `:847` | `reminder_clicked` (legacy bare-id payload) | `'unknown'` |
| 18 | same `:1057` | `reminder_set` | `'unknown'` |
| 19 | same `:1064` | `reminder_scheduled` | `'unknown'` |
| 20 | same `:834` | `activity_upload_notification_clicked` | `'unknown'` |
| 21 | same `:1191` | `activity_upload_notification_shown` | `'unknown'` |

The services in rows 11-14 are built in `macro_targets_controller.dart` (`:695`, `:944`, `:1228`, `:1500`) and `activity_detail_controller.dart` (`regeneratePlan`, `:367`, `:386`, `:408`); both get the device id injected. Rows 20-21 are not reminder events but send `'unknown'` from the same file, so they are fixed here too (the exit box says none sends `'unknown'`). `NotificationService.configure` is called from `lib/features/app_startup/application/app_startup_service.dart:535`, which passes the device info service in.

Left as they are (checked, not analytics with a wrong id):
- `app_startup_service.dart:545` `app_opened`: already `DeviceInfoService.instance.deviceId`.
- `onboarding_service.dart:60` `user_registered` (ticket 104) and the eight integration events in `connect_training_controller.dart` (ticket 60): already the device id.
- `analytics_tracker.dart:161` `anonymous_user_identified`: sends the id passed to `identifyUser`, and the only anonymous caller (`app_startup_service.dart:531`) passes the device id.
- `requestData['device_id']` in `macro_generation_service.dart:98,164,239` and `brick_macro_service.dart:84`, and `nutrition_plan_service.dart:124`: the edge-function request body, where the server reads it as the user id. Not analytics; unchanged.
- Every other `device_id` hit is a database column, repository write or domain field, not an analytics event.

Left for the lead: none (no site sits in a forbidden file).

**Questions for Lee.** None.

## Exit
- [x] Every listed event sends the device id; none sends the user id or `'unknown'`.
- [x] Analytics fake tests updated; `grep -rl` each changed class under `test/` and run those files (#116).
- [x] `flutter analyze` clean on touched files.
- [ ] Retest: console check in retest ticket 69 (an activity event and a reminder event carry a device id that is not the user id).

Next: /testing-wave develop-2026-10 (fix wave 6)

## Fix notes

Agent, 2026-10-08, branch `testing-wave/develop-2026-10/70`, code commit `80e16c06`.

**Notification rule.** The `notification-testing` skill and `ops/docs/messaging-relay-and-testing.md` are not on this machine (IMPROVEMENTS #101/#123). Instead I read `lib/shared/services/notification_service.dart` in full (all 1308 lines: OneSignal arming, tap dispatch, legacy launch/resume payloads, `scheduleReminder`, the activity-upload notification, carb nudges) and the startup chain that configures it (`app_startup_service.dart` `deferred.notifications` → `deferred.device_info` → `deferred.analytics`, where `configure` runs). Only the `device_id` value of six analytics calls changed. Scheduling, ids, channels, payload strings and navigation dispatch are untouched.

**All 21 sites, before → after:**

| # | Site | Event | Before | After |
|---|---|---|---|---|
| 1-8 | `macro_targets_controller.dart` `generateMacros` / `generateCyclingMacros` / `generateSwimmingMacros` / `generateBrickMacros` | `plan_generation_started` / `plan_generation_failed` | user id (`'unknown'` on an early failure) | `analyticsDeviceId`, read from `_analyticsDeviceId` (`ref.read(deviceInfoServiceProvider).deviceId`) before the guard |
| 9-10 | `macro_targets_controller.dart` `createNutritionPlan` → `_trackPinDecisions` → `_emitPinEvent` | `plan_used_pin` / `plan_pin_fallthrough` | `userProfile?.id ?? 'unknown'` | `analyticsDeviceId`, read at the top of `createNutritionPlan` |
| 11-13 | `macro_generation_service.dart` running / cycling / swimming | `plan_generated` | `deviceId` param (user id) | new required ctor field `analyticsDeviceId` |
| 14 | `brick_macro_service.dart` | `plan_generated` | user id | new required ctor field `analyticsDeviceId` |
| 15 | `activity_card.dart` `_handleTap` | `activity_viewed` | `activity.userId` | `ref.read(deviceInfoServiceProvider).deviceId` |
| 16-17 | `notification_service.dart` `_handleNotificationPayload` (typed + legacy) | `reminder_clicked` | `'unknown'` | `_analyticsDeviceId` |
| 18-19 | `notification_service.dart` `scheduleReminder` | `reminder_set` / `reminder_scheduled` | `'unknown'` | `_analyticsDeviceId` |
| 20 | `notification_service.dart` `_handleNotificationPayload` | `activity_upload_notification_clicked` | `'unknown'` | `_analyticsDeviceId` |
| 21 | `notification_service.dart` `showActivityUploadedNotification` | `activity_upload_notification_shown` | `'unknown'` | `_analyticsDeviceId` |

The services in rows 11-14 are built with `analyticsDeviceId` in `macro_targets_controller.dart` (four sites) and `activity_detail_controller.dart` `regeneratePlan` (three sites; read before its first await). The `deviceId` the generate methods take is still the user id and still goes into the edge request's `device_id` (the server reads it as the user); the plan seam test asserts that too. `NotificationService` is static, so `configure` gained an optional `DeviceInfoService? deviceInfo` (kept when a later `configure` omits it, cleared by `debugReset`; null falls back to `DeviceInfoService.instance`, the same singleton the provider returns). `app_startup_service.dart` passes `ref.read(deviceInfoServiceProvider)`.

**Files:** `lib/features/nutrition_plan/presentation/providers/macro_targets_controller.dart`, `lib/features/nutrition_plan/application/macro_generation_service.dart`, `lib/features/nutrition_plan/application/brick_macro_service.dart`, `lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart`, `lib/features/activities/presentation/widgets/activity_card.dart`, `lib/shared/services/notification_service.dart`, `lib/features/app_startup/application/app_startup_service.dart`; tests `test/features/nutrition_plan/presentation/providers/plan_generated_device_id_test.dart` (new), `test/shared/services/notification_tap_device_id_test.dart` (new), `test/features/activities/presentation/widgets/activity_card_test.dart` (one new test). No `@riverpod` signature changed, so no codegen. No catch added, so no source-guard run (#117). No notifier state touched (#118).

**Async notes (twice at once, or after a refresh):**
- Generate methods and `createNutritionPlan`: the id is a synchronous read of a stateless singleton, taken before the first await. Two runs at once read the same value; an invalidate or refresh of the controller does not touch `DeviceInfoService`, so a run that outlives a refresh still holds the id it read.
- `regeneratePlan`: read before `getCurrentUser()`; a dispose mid-flight cannot hit `ref` for it afterwards.
- `activity_card` tap: synchronous read in the tap handler, no await before it.
- `NotificationService`: read synchronously when each event fires. Concurrent taps read the same id. A cold-start tap is handled in `deferred.notifications`, before `deferred.device_info`, but `_analytics` is still the no-op tracker then (`configure` runs later, in `deferred.analytics`), so nothing leaves the device and the uninitialized fallback id is never sent. That ordering is unchanged from before.

**Tests (no simulators, no full suite):**
- New seam tests, each with `deviceInfoServiceProvider` (or `configure(deviceInfo:)`) overridden by a fake whose id is not the user id: plan (real `ActivityDetailController.regeneratePlan`, edge call fails with a host lookup error so the production offline fallback runs, no fabricated server response; asserts `plan_generated.device_id` = device id and request `device_id` = user id), activity (tap on the real card), reminder (four tests: typed and legacy `reminder_clicked`, `activity_upload_notification_clicked`, `configure` without a device info keeps the earlier one). Mutation check: putting the user id back on the running `plan_generated` turns the plan test red.
- `reminder_set` / `reminder_scheduled` are not unit-tested: `scheduleReminder` returns at the plugin permission check before tracking, and a unit test has no platform plugin. They use the same getter as the tested taps; retest 69 covers them on the console.
- #116 run: every file `grep -rl` named for `MacroGenerationService`, `BrickMacroService`, `MacroTargetsController`/`macroTargetsControllerProvider`, `regeneratePlan`, `ActivityCard`, `NotificationService`, the pin event names and `device_id` (33 files, excluding the `@Tags(['e2e'])` `test/e2e/dev_cloud_e2e_test.dart`, which calls the live dev backend): **342 passed, 3 skipped, 0 failed.**
- `flutter analyze` on the 10 touched files: **No issues found.**

**Not met:** the retest box (ticket 69's console check is a later wave).

