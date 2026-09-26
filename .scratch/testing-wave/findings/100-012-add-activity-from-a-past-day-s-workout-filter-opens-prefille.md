# 100-012 · Add Activity from a past day's Workout filter opens prefilled with 12 mi Run

- kind: followup-test
- status: open
- ticket: 100
- run: w39-20260926T1013Z
- screen: Timeline (Workout filter) > + Add Activity
- decision: 

**Steps.**
1. test@test.com, Timeline on Sep 25 with the Workout filter.
2. Tap + Add Activity.

**Expected.**
An empty new-activity form for Sep 25.

**Actual.**
Seen once by accident: the form opened on "Create New Activity Plan" already filled with "12 mi Run", 12.0 mi, Sep 25 7:00 am. Not followed up; Back without saving. Check where the prefill comes from and whether Generate Plan would make a duplicate of an existing run.

**Evidence.**
- runs/100/61-log-a-meal.png

**Decision quote.**
> 

**Triage.**

