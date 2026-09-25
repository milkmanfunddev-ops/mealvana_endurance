# 31-005 · Profile & Preferences: leave with unsaved changes by the back arrow and by swipe-back

- kind: followup-test
- status: triaged
- ticket: 31
- run: w11-20260924T1648Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. Open Profile & Preferences and change one field without saving.
2. Leave by the orange back arrow; reopen. Repeat with the iOS swipe-back gesture.

**Expected.**
The app either asks to discard changes or drops them; the database is unchanged either way.

**Actual.**
Not run.

**Evidence.**
- 

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 93 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 119 when 93 was split (Lee, 2026-09-25).
