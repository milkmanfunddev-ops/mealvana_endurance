# 14-003 · Plan tab right after login listed a fifth meal that no plan on dev holds, gone seconds later

- kind: bug
- status: closed
- ticket: 14
- run: w8-20260924T1418Z
- screen: Plan tab
- decision: 

**Steps.**
1. App signed out on the welcome screen (simulator copied from the dev simulator). Log in with email as test@test.com (14:20:20Z).
2. Timeline opens. Tap Food; the Plan tab opens (14:21:06Z).
3. Scroll the Plan tab about 45 s later (14:21:53Z).

**Expected.**
The Plan tab lists the meals of the confirmed plan be6abf2f: 4 dinners.

**Actual.**
At 14:21:06Z the header read "Sep 20 – Sep 26 · 5 meals" and listed a fifth dinner, "Brown rice, zucchini & chickpea bowl". No `plan_meals` row on dev has that name for any user, and the local Drift database had no such row when read at 14:22Z. By 14:21:53Z the tab read 4 meals and the dinner was gone. Where the fifth row came from is unknown: a stale local row removed by the sync is likely (see 14-004).

**Evidence.**
- runs/14/01-plan-tab-before.png — 5 meals incl. Brown rice, zucchini & chickpea bowl.
- runs/14/02-plan-tab-synced-4-meals.png — 4 meals 47 s later.
- runs/14/db-before.txt — be6abf2f has 4 meals on dev.

**Decision quote.**
> 

**Triage.**
Fix ticket 33 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 86 (run w25-20260925T1324Z, build 5e05f8a6): pass, evidence in runs/86/verdicts.md.
