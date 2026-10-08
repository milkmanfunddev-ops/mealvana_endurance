# 08-022 · Follow-up: deep links with the two-slash form, and while signed out

- kind: followup-test
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: Page Not Found
- decision: 

**Steps.**
1. Open com.milkman.mealvanaendurance://athlete/feedback (two slashes): it shows 'Page Not Found'; its Go Home landed on the logo (startup) screen. Check where Go Home settles. Then open each route-only path while signed out: the redirect guard should send to Welcome.

**Expected.**
Go Home settles on the Timeline; signed-out deep links never show a signed-in screen.

**Actual.**


**Evidence.**
- runs/08/c00-two-slash-form.png

**Decision quote.**
> 

**Triage.**
retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets)

**Closed (wave 3, 2026-10-08).** signed-out half passes in ticket 32; Go Home re-filed as 32-002
