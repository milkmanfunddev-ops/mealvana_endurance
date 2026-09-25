# 21-002 · Shop with Kroger opens the system location prompt, whose reason text talks about weather forecasts
- kind: bug
- status: closed
- ticket: 21
- run: w17-20260924T2233Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Fresh app data (wave simulator), sign in as test@test.com.
2. Food > Shopping > Shop with Kroger (22:36:09 UTC).

**Expected.**
If the Kroger screen asks for location to find a delivery area, the system prompt's reason says so (groceries, delivery area), or the app explains first.

**Actual.**
The first thing on screen is iOS's "Allow “Endurance Dev” to use your location?" with the reason "This app uses your location to provide accurate weather forecasts for your upcoming activities, helping you plan your nutrition and hydration needs based on local conditions." (`ios/Runner/Info.plist`, `NSLocationWhenInUseUsageDescription`). Nothing about Kroger or delivery. An athlete who taps Don't Allow here also turns off location for weather, and iOS only asks once. This run tapped Don't Allow; the screen then showed "Set delivery ZIP".

**Evidence.**
- runs/21/09-location-prompt-on-shop-with-kroger.png
- runs/21/10-kroger-screen.png

**Decision quote.**
> 

**Triage.**
Fix ticket 56 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 111 when 90 was split (Lee, 2026-09-25).

Run by retest ticket 111 (run w30-20260925T2103Z, build e3367d2c): pass.
