# 03-004 · A fresh install asks for notification permission at launch, before the welcome screen and with no context

- kind: idea
- status: closed
- ticket: 03
- run: w3-20260923T1942Z
- screen: Splash (before Welcome)
- decision: 

**Steps.**
1. Install the dev app fresh and launch it.

**Expected.**
The notification permission is asked when it means something to the athlete (after signup, or
where reminders are turned on), so the first thing a new install shows is Mealvana's welcome.

**Actual.**
iOS's "Endurance Dev Would Like to Send You Notifications" alert covers the splash before the
welcome screen. Deferred startup step 3 (`NotificationService.initialize`) calls OneSignal's
`requestPermission(false)` on every launch to refresh the APNs token (commit 39535a7a); on an
install that has never answered, that call shows the system prompt. The code comment says it is
deliberate, so this is an idea, not a bug. It also stalled every Patrol flow until the test
launcher learned to answer it (test code, this ticket).

**Evidence.**
- runs/03/attempt1-notification-prompt-over-splash.png
- runs/03/patrol-suite-attempt1.log (activities_crud and auth wait out their timeouts)
- lib/shared/services/notification_service.dart, `_initializeOneSignal`

**Decision quote.**
> 

**Triage.**
Fix ticket 79 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.

Closed by retest ticket 86 (run w25-20260925T1324Z, build 5e05f8a6): pass, evidence in runs/86/verdicts.md.
