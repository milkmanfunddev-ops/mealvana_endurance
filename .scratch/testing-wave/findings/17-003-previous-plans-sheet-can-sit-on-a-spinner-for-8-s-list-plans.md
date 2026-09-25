# 17-003 · Previous plans sheet can sit on a spinner for 8 s (list_plans took 8062 ms)

- kind: bug
- status: closed
- ticket: 17
- run: w12-20260924T1712Z
- screen: Previous plans (sheet)
- decision: 

**Steps.**
1. Signed in as test@test.com, open an earlier plan from Previous plans, tap Back.
2. Plan tab → ⋮ → Previous plans again.
3. Wait 5 s and tap a row.

**Expected.**
The list shows within a second or two; the sheet reads a short list.

**Actual.**
Five seconds after the tap only the spinner showed, and the tap meant for a row landed on the scrim and closed the sheet. The edge log has `list_plans` at 17:17:05 UTC taking 8062 ms (other calls in the run took 1080, 1238 and 1507 ms). `listPlans` counts each plan's meals with a separate query, one after another, 20 round trips per open, and the sheet reads the list afresh on every open (`previousPlansProvider` is auto-disposed). Seen once; the next open loaded in about a second.

**Evidence.**
- runs/17/edge-function_logs.txt — `type=list_plans parts=- 8062ms` at 12:17:05 local.
- runs/17/13-sheet-loading.png — the spinner state of the sheet.
- runs/17/12-plan-tab-sheet-not-loaded-tap-dismissed.png — the Plan tab after the tap closed the unloaded sheet.

**Decision quote.**
> 

**Triage.**
Fix ticket 49 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 89 (run w29-20260925T1950Z, build e3367d2c): pass, evidence in runs/89/verdicts.md. Side problems filed as 89-005.
