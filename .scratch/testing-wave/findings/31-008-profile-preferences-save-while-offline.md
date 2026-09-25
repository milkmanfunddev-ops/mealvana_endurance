# 31-008 · Profile & Preferences: save while offline

- kind: followup-test
- status: triaged
- ticket: 31
- run: w11-20260924T1648Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. Turn the simulator's network off.
2. Toggle the water bottle and tap Save Changes.
3. Relaunch offline, then online; read the column by SQL.

**Expected.**
The change is saved locally and uploaded when back online (offline-first rule), with no success message that hides a failed save.

**Actual.**
Not run.

**Evidence.**
- 

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 93 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
