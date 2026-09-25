# 86-003 · Plan tab opened within seconds of login, while the account's own stale local plan rows are still there

- kind: followup-test
- status: triaged
- ticket: 86
- run: w25-20260925T1324Z
- screen: Plan tab
- decision: 

**Steps.**
1. Start from a phone whose local database holds an older copy of the account's own confirmed plan (here
   be6abf2f held locally as `draft` with a fifth meal, "Brown rice, zucchini & chickpea bowl", that dev no
   longer has).
2. Log in and open Food → Plan within 5-10 s, before the first plan sync finishes; screenshot every second
   until it settles.

**Expected.**
The Plan tab never lists a meal the plan on dev does not hold, even for a moment.

**Actual.**
Not run as such. In this run the local copy read at 13:26:42Z (24 s after login) still held the 5-meal
draft copy of be6abf2f; the Plan tab opened at 13:27:05Z (47 s, the same timing as Finding 14-003) showed the
correct 4 meals, so 14-003's steps pass. The stray row is the account's own stale row, not another account's,
so ticket 33 does not remove it; an earlier look at the Plan tab may still show it.

**Evidence.**
- runs/86/local-plans-after-login.txt (be6abf2f draft, 5 meals, at 13:26:42Z)
- runs/86/04-food-tab.png (4 meals at 13:27:05Z)

**Decision quote.**
> 

**Triage.**
Picked for retest ticket 107 (Lee, 2026-09-25).
Moved to retest ticket 120 when 107 was split (Lee, 2026-09-25).
