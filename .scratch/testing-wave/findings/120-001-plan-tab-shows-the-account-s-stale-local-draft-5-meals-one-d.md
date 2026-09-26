# 120-001 · Plan tab shows the account's stale local draft (5 meals, one dev no longer has) for about a second after login

- kind: bug
- status: triaged
- ticket: 120
- run: w39-20260926T1013Z
- screen: Food → Plan
- decision: 

**Steps.**
Retest of 86-003. Simulator wave-pool-2, app build 72d3723e, app data not cleared (leftover from the dev simulator).
1. Before launch the local database holds test@test.com's plan be6abf2f (week 2026-09-20) as `draft` with 5 meals, one of them "Brown rice, zucchini & chickpea bowl"; dev holds be6abf2f as `archived` without that meal, and this week's confirmed plan is 9be88811 with 1 meal, "Sweet rice cake with jam".
2. Log in as test@test.com (10:17:32Z), tap Food the moment the tabs show (10:17:38Z), screenshot about every 0.6 s.

**Expected.**
86-003: the Plan tab never lists a meal the plan on dev does not hold, even for a moment.

**Actual.**
The first Plan tab frame (10:17:38Z, about 6 s after Log In) reads "Sep 20 – Sep 26 · 5 meals" and lists the stale local draft be6abf2f, "Brown rice, zucchini & chickpea bowl" included. From the next frame (10:17:39Z) on it reads "1 meal", Sweet rice cake with jam (dev's 9be88811). Any phone updated from an older build carries such stale rows of its own account; ticket 102 sweeps only other accounts' rows, so the account's own stale plan still shows until the first pull lands.

**Evidence.**
- runs/120/08-plan-tab-stale-5-meals-101738.png (5 meals, Brown rice bowl)
- runs/120/09-plan-tab-1-meal-101739.png (1 meal, a second later)
- runs/120/07-login-plan-sequence-sheet.png (the whole sequence)
- runs/120/local-plans-00-before-launch.txt (stale be6abf2f draft, 5 meals)
- runs/120/db-00-test-plans-before.txt (dev: be6abf2f archived, 9be88811 confirmed)

**Decision quote.**
> 

**Triage.**

Fix ticket 134, Meal plans and Vana (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
