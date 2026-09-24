# 19-004 · Food Plan sub-tab says No plan yet for about 6 s after login while the confirmed plan loads

- kind: bug
- status: open
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Plan sub-tab)
- decision: 

**Steps.**
1. Cleared app, sign in as test@test.com (confirmed plan be6abf2f for week 2026-09-20), close the What's New and TrainingPeaks sheets.
2. Tap Food straight away (about 16:50Z).
3. Look again 6 s later.

**Expected.**
A loading state until the plan is read, then the plan (the same point as 16-003 for the Shopping sub-tab).

**Actual.**
The Plan sub-tab first showed the empty state "No plan yet. Vana will build one with you ..." with Add meal and New meal plan, and Vana's card read "Looking at your day...". About 6 s later it showed "Sep 20 - Sep 26 · 4 meals" and the four meals. An athlete who taps New meal plan in that window starts a new plan while one is confirmed. The empty state was seen through the MCP screenshot only; the file screenshot was taken after the plan had loaded.

**Evidence.**
- runs/19/notes.md: the 16:50:34Z line records the ~6 s No plan yet.
- runs/19/03-food-plan.png: the plan after it loaded.

**Decision quote.**
> 

**Triage.**
