# 22-001 · consumeLegacyResumeTap has no caller: backgrounded notification taps are never collected and their payload keys never cleared

- kind: bug
- status: open
- ticket: 22
- run: w2-20261007T1340Z
- screen: none (startup chain, NotificationService)
- decision: 

**Steps.**
1. Build the dev app, sign in, send yourself a local or OneSignal notification and background the app.
2. Tap the notification while the app is backgrounded (not killed).
3. Grep `lib/` for callers of `NotificationService.consumeLegacyResumeTap()`.

**Expected.**
The tap is collected on resume and routed; `ios_un_response_payload` / `ios_legacy_resume_payload` are cleared after being read.

**Actual.**
Filed by the wave lead from the wave 2 code review (ticket 22's startup telemetry). `consumeLegacyResumeTap()` is defined at `lib/shared/services/notification_service.dart:876` and has no caller anywhere in `lib/`. A tap that lands while the app is backgrounded is never collected, and the two payload keys it would clear stay set until the next cold start reads them (LaunchTrail only tapes them). Unverified on a device; the method exists and nothing calls it.

**Evidence.**
- `lib/shared/services/notification_service.dart:876` (definition; `grep -rn consumeLegacyResumeTap lib` shows only it)
- `lib/shared/services/launch_trail.dart:45` (the keys, taped but never cleared)

**Decision quote.**
> 

**Triage.**
lead-filed; needs Lee's ruling (fix ticket for wave 4, with the notification-testing skill first).

