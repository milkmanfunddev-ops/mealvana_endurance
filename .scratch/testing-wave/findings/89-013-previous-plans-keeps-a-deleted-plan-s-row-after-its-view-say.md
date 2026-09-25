# 89-013 · Previous plans keeps a deleted plan's row after its view says This plan is no longer here

- kind: bug
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Previous plans (sheet)
- decision: 

**Steps.**
1. Throwaway account with two confirmed plans (A 7fec0368 archived, B e9e5e1f0 current). Plan ⋮ > Previous plans: A is listed.
2. Delete A elsewhere (vana-action delete_plan as the same user, 20:32:40Z).
3. Tap A's row (20:32:42Z), then Back.

**Expected.**
The view says the plan is gone (it does), and the sheet drops the row it now knows is gone.

**Actual.**
The view shows "This plan is no longer here." (pass for 17-005 step 3). Back returns to the sheet with A's row still there; tapping it again gives the same message. Reopening the sheet re-reads the list.

**Evidence.**
- runs/89/97-17-005-sheet-before-delete.png: A listed.
- runs/89/98-17-005-deleted-plan-opened.png: "This plan is no longer here."
- runs/89/99-17-005-back-after-deleted.png: the row still in the sheet.

**Decision quote.**
> 

**Triage.**

Fix ticket 130 (Lee, 2026-09-25). Closed by the retest after it merges.
