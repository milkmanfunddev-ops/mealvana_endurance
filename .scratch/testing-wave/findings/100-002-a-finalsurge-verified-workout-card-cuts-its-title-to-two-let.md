# 100-002 · A FinalSurge-verified workout card cuts its title to two letters (Swim reads SW...) behind the verified badge

- kind: bug
- status: open
- ticket: 100
- run: w39-20260926T1013Z
- screen: Timeline (Workout filter), Fri Sep 25
- decision: 

**Steps.**
1. test@test.com, Timeline, Previous day to Sep 25, filter Workout.
2. Look at the FinalSurge swim completed by the provider (18f023ed…, 7:25 PM).

**Expected.**
The card shows the workout name ("Swim") next to the "verified · Final Surge" badge.

**Actual.**
The name is cut to "SW…" (two letters): the badge takes the rest of the row. The element label still reads "Swim", so only the drawn text is cut. Longer names would show nothing useful.

**Evidence.**
- runs/100/33-sep25-workouts.png

**Decision quote.**
> 

**Triage.**

