# 68-003 · Retest of 49-007: Camera with camera access turned off says only 'Could not access the camera or gallery.' and reports a degraded PlatformException

- kind: bug
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: Log a Meal > Describe > Camera
- decision: 

**Steps.**
1. Retest of 49-007 step 3. Camera access had been granted earlier in the run (check 7).
2. xcrun simctl privacy UDID revoke camera com.milkman.mealvanaendurance.dev (iOS ended the app; relaunched it).
3. Log a Meal > Describe, tapped Camera at 23:23:22Z.

**Expected.**
A message that explains itself: camera access is off for Mealvana, and how to turn it on (Settings), the way the barcode scanner's 'Camera access is off. …' copy does.


**Actual.**
A snackbar 'Could not access the camera or gallery.' It does not say access is off or where to fix it, and it names the gallery, which was not tapped. The console sends error_reported {severity: degraded, area: meal_logging, exception_type: PlatformException, sentry_event_id: aa08b3b82eb748d88f081077209adf35}: an athlete's own permission choice lands in Sentry as a degraded error.


**Evidence.**
- runs/68/06d-camera-after-revoke.png: the snackbar.
- runs/68/console-redacted.log: error_reported PlatformException at 18:23:22 local.

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 81 (geocode no-match and camera-denied are expected outcomes with copy that says what to do; process_uptime_ms from the real process start), fix wave 8 · Lee, 2026-10-09
