# 49-001 · Back on a deep-linked Connected Apps lands a signed-in athlete on Welcome (back fallback go('/') resolves to Welcome)

- kind: bug
- status: open
- ticket: 49
- run: w5-20261008T1719Z
- screen: Connected Apps
- decision: 

**Steps.**
1. Signed in as test@test.com (onboarded), on the Timeline (17:22:18Z).
2. `xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///settings/connected-apps"`, Open in the iOS confirm (17:22:59Z). Connected Apps opens.
3. Tap the back arrow at top left (17:23:12Z).

**Expected.**
Back lands on the Timeline (or wherever home is for a signed-in, onboarded athlete). The fallback code says "Home is always a correct back from a dead-end" and calls `go('/')`, which the router is meant to resolve to `/main` for this athlete (ticket 46's Decision: "`/` is the one path the redirect resolves from app state").

**Actual.**
Welcome ("Get more out of every session.", Build My Plan / I already have an account) while still signed in. Console 12:23:12.527 local: `[LAUNCH] back fallback: canPop=false — going home`. A relaunch at 17:25:24Z opened signed in (TrainingPeaks sharing sheet, then the Timeline), so the session was never lost: the root redirect sent a signed-in athlete to Welcome. A tap on "I already have an account" would then ask to log in again. Found incidentally (the deep link was a shortcut for a read-only look); the deep-link and notification skill's paths were not tested further by this run.

**Evidence.**
- runs/49/05-connected-apps.png — Connected Apps opened by the deep link
- runs/49/06-back-from-connected-apps-welcome.png — Welcome after Back, signed in
- runs/49/08-timeline-after-relaunch.png — relaunch: still signed in
- runs/49/console-redacted.log — `back fallback: canPop=false — going home` at 12:23:12 local

**Decision quote.**
> 

**Triage.**
