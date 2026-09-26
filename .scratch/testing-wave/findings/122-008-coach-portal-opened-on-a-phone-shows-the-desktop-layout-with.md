# 122-008 · Coach Portal opened on a phone shows the desktop layout with overflow stripes

- kind: bug
- status: wontfix
- ticket: 122
- run: w38-20260926T0340Z
- screen: Coach Portal
- decision: 

**Steps.**
1. Sign in as test@test.com on the iPhone simulator.
2. `xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///coach-portal"`, Open.

**Expected.**
Either the route is refused on a phone (it is web-only by design), or it lays out for a phone.

**Actual.**
The two-pane desktop layout opens: the athlete list takes two thirds of the width, and the detail pane is squeezed into a strip. The name "Dirk Friel 2" wraps one letter per line, with yellow/black "RIGHT OVERFLOWED BY 23 PIXELS" and "BY 85 PIXELS" stripes. The route is registered on iOS but only web code navigates to it, so a user reaches it only by link. Low. It matters if 122-002 is fixed by showing this portal on phones.

**Evidence.**
- runs/122/35-coach-portal.png

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-26): coach-code pairing now auto-accepts (ticket 140), so no phone path to the Coach Portal is needed.
