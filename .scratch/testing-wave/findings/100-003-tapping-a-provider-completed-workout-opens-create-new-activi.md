# 100-003 · Tapping a provider-completed workout opens Create New Activity Plan with Generate Plan

- kind: bug
- status: triaged
- ticket: 100
- run: w39-20260926T1013Z
- screen: Timeline workout card > activity editor
- decision: 

**Steps.**
1. test@test.com, Timeline, Sep 25, filter Workout.
2. Tap the "Swim · verified · Final Surge · 1.0 mi · 34 min" card (FinalSurge completion, completion_type provider).

**Expected.**
The completed workout's detail (what was done, the fuel plan), or an edit screen named as such. Ticket 101: a provider completion is final for the athlete.

**Actual.**
The screen headed "Create New Activity Plan" opens with Swimming selected, Sep 25 7:25 pm, name Swim, distance 2000.0 m (the planned value) and a "Generate Plan" button. Went Back without saving, so what Generate Plan does to a provider-completed activity is untested. (Before this, the tap raised the iOS location prompt, 100-004.)

**Evidence.**
- runs/100/35-swim-detail.png
- runs/100/db-fs-completed-activities.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 137, Timeline and activities (Lee, 2026-09-26). Ruling: tapping a provider-completed workout opens its activity detail, never Create New Activity Plan (137). Closed by the retest after it merges. Record: `triage-20260926.md`.
