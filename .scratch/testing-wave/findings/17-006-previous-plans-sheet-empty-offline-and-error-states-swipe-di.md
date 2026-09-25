# 17-006 · Previous plans sheet: empty, offline and error states, swipe-dismiss, and tapping during load

- kind: followup-test
- status: closed
- ticket: 17
- run: w12-20260924T1712Z
- screen: Previous plans (sheet) and the Plan tab ⋮ menu
- decision: 

**Steps.**
1. On a new account with one plan (or none), open Previous plans: the empty text should show.
2. Turn the network off, open Previous plans: the "failed" text should show, and the sheet should recover when the network is back and it is opened again.
3. Swipe the sheet down while it loads and after; reopen at once.
4. Open it on an account with no plan on the Plan tab (the current-plan id is null): the client's filter must not drop anything else.
5. The ⋮ menu beside the sheet also offers Start a new plan and Delete plan, which change plans; not tapped in this read-only run (14-007 covers them).

**Expected.**
Each state shows its own text; nothing hangs; the list matches SQL afterwards.

**Actual.**
Not run (followup).

**Evidence.**
- runs/17/07-plan-options-menu.png — the menu.
- runs/17/13-sheet-loading.png — the loading state.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 89 (Lee, 2026-09-25).

Run by retest ticket 89 (run w29-20260925T1950Z, build e3367d2c): fail, filed as 89-011, 89-012; closed here, the new Findings carry it.
