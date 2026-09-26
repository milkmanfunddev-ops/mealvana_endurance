# 100-004 · Opening a past day's workout card asks for location for the weather forecast

- kind: idea
- status: triaged
- ticket: 100
- run: w39-20260926T1013Z
- screen: Timeline workout card (past day)
- decision: 

**Steps.**
1. test@test.com, fresh install, Timeline, Sep 25 (yesterday), Workout filter.
2. Tap the completed Swim card.

**Expected.**
No location prompt for a workout that is already over; the weather forecast reason does not apply to a past day.

**Actual.**
iOS asked "Allow “Endurance Dev” to use your location?" with the reason "Your location is used for the weather forecast at your upcoming activities…". Chose Don't Allow. The prompt is spent on a screen where the forecast cannot matter, so the athlete may refuse it before it is useful.

**Evidence.**
- runs/100/34-sep25-swim-detail.png

**Decision quote.**
> 

**Triage.**

Fix ticket 137, Timeline and activities (Lee, 2026-09-26). Ruling: location is asked for only on an upcoming activity with a forecast (137). Closed by the retest after it merges. Record: `triage-20260926.md`.
