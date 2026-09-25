# 14-007 · Plan tab menu: Start a new plan and Delete plan while a new-plan draft is open

- kind: followup-test
- status: closed
- ticket: 14
- run: w8-20260924T1418Z
- screen: Plan tab (⋮ menu)
- decision: 

**Steps.**
1. Plan tab → ⋮ beside "Sep 20 – Sep 26". 2. Tap Start a new plan: does it open the same new-plan chat as the button? 3. With a new-plan draft half built, tap Delete plan on the confirmed plan, then go back to the draft and confirm it.

**Expected.**
Start a new plan behaves like New meal plan. Deleting the confirmed plan leaves the draft alone, and confirming the draft then works and archives nothing unexpected.

**Actual.**
Not run (followup). The menu shows Start a new plan, Previous plans, Delete plan.

**Evidence.**
- runs/14/09-plan-header-menu.png — the menu.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Closed by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): pass, evidence in runs/88/verdicts.md. Side problems filed as 88-019.
