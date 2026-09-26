# 100-011 · 29-002 again on a day FinalSurge sends a completed workout for today

- kind: followup-test
- status: open
- ticket: 100
- run: w39-20260926T1013Z
- screen: Timeline; FinalSurge sync
- decision: 

**Steps.**
1. On a day the dev FinalSurge feed has a workout with WorkoutCompleted true for today, sign in as test@test.com.
2. Read the payload, the activity row and the card.

**Expected.**
Status completed, completed_at set, actual_* set, completion_type provider, planned fields unchanged, card done with no Undo.

**Actual.**
Not run today: every workout in the 10:23Z fetch was WorkoutCompleted false. The Sep 25 swim (18f023ed) already shows the fixed behaviour.

**Evidence.**
- runs/100/db-fs-completed-activities.txt
- runs/100/33-sep25-workouts.png

**Decision quote.**
> 

**Triage.**

