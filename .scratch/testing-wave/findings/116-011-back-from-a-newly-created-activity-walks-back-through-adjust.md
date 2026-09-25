# 116-011 · Back from a newly created activity walks back through Adjust Your Macros and Create New Activity Plan instead of the timeline

- kind: bug
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: Activity detail (after Create Plan)
- decision: 

**Steps.**
1. New account (lee+e2e-116-20260925T2258Z). Timeline > + Add Activity: 12 mi Run, Generate Plan, then Create Plan on Adjust Your Macros (23:00Z).
2. On the new activity's screen tap Back, then Back again.

**Expected.**
Back from the created activity returns to the timeline.

**Actual.**
The first Back lands on "Adjust Your Macros" (During this Run, Create Plan button still live), the second on "Create New Activity Plan" with the form filled, the third on the timeline. Only one activity row exists (no duplicate was made), but a tap on Create Plan or Generate Plan from there could make one.

**Evidence.**
- runs/116/92-acct2-generated.png
- runs/116/93-acct2-12mi-run-during.png
- runs/116/94-back-lands-adjust-macros.png

**Decision quote.**
> 

**Triage.**

