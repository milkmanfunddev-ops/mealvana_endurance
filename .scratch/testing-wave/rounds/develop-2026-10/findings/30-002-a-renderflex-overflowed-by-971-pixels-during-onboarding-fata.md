# 30-002 · A RenderFlex overflowed by 971 pixels during onboarding (fatal FlutterError in dev Sentry, MEALVANA-ENDURANCE-DEV-B1)

- kind: bug
- status: open
- ticket: 30
- run: w3-20261008T1255Z
- screen: Tell us about yourself
- decision: 

**Steps.**
1. Fresh install, app launched 12:56:42Z (netcut launch). Welcome → Build My Plan (offline for the tap, network back at 12:57:10Z).
2. Running → goal → obstacle → Continue past the training-app page.
3. On "Tell us about yourself", tap First name, Last name and Email address in turn and type into each (keyboard up), 12:57:50Z-12:58:20Z.

**Expected.**
No layout overflow on any onboarding page, keyboard up or not.

**Actual.**
Dev Sentry got a `level: fatal`, `handled: no` FlutterError "A RenderFlex overflowed by 971 pixels on the bottom." at 12:58:11Z
from this simulator (`app_start_time` 12:56:42Z = this run's launch, view_names `onboarding`, iOS 26.2 simulator, build
1.29.0+6). The overflowing widget is a vertical `Column ← MediaQuery ← Padding ← SafeArea ← … ← Scaffold body`.
The page in front at that second was "Tell us about yourself" with the keyboard up (from the run's timeline;
the event names no route, so the page is unverified). Nothing showed as broken on screen in the screenshot
taken just after typing, and the console stream does not carry FlutterError dumps, so the only record is Sentry.
A 971 px overflow is larger than the keyboard, so it may come from another page built offstage in the page view.

**Evidence.**
- runs/30/sentry-30a.md (event ba3e81d087934a2aa441845a11d44049, issue MEALVANA-ENDURANCE-DEV-B1)
- runs/30/30a-07-personal-info.png

**Decision quote.**
> 

**Triage.**
