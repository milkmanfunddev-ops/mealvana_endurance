# 112-012 · Re-logging from Recent at 2 servings makes the doubled meal Recent's new 1-serving base

- kind: idea
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Recent)
- decision: 

**Steps.**
1. Recent shows one row per meal name, the newest log. After re-logging "Oatmeal + raisins" at 2 servings (23:24:41Z), its Recent row reads 408 kcal, and its sheet at servings 1 logs 408 kcal. Idea: keep the per-serving base (the original's totals) on the Recent row, or show "2 servings" on it, so a second re-log does not silently double again. The same applies to a 1.5x log. The first "Rice cake and Almond butter" (9162543b, two items) is no longer reachable from Recent at all, because the newest same-named row (00a120e5, the one-line copy from 26-002) hides it.

**Expected.**
Triage decides what one serving of a Recent meal means.

**Actual.**


**Evidence.**
- runs/112/19-recent-top-saved.png
- runs/112/db-run-rows.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 135, Meal upload and quick logging (Lee, 2026-09-26). Ruling: a Recent row keeps the meal's per-serving numbers, so 1 serving always means the original amount. Same-named meals with different items both show (135). Closed by the retest after it merges. Record: `triage-20260926.md`.
