# 120-002 · A pull archives this week's newer draft locally while dev keeps it as a draft

- kind: bug
- status: open
- ticket: 120
- run: w39-20260926T1013Z
- screen: Food → Plan
- decision: 

**Steps.**
Retest of 86-002.
1. Log in as test@test.com on a phone holding its older rows (10:17:32Z).
2. After the first sync (10:18:31Z) compare the local meal_plans of week 2026-09-20 with dev.

**Expected.**
86-002: the local status of each plan matches dev's once sync has run, or the difference is deliberate and written down.

**Actual.**
Dev holds 50390c90 as `draft` (created 2026-09-26 00:48Z, after 9be88811 was confirmed at 2026-09-25 22:33Z). The local copy holds 50390c90 as `archived`, clean (needs_upload 0), updated_at 10:17:41Z, the same second 9be88811 was applied. By code reading: `MealPlanRepository.applyServerPlan` (lib/features/meal_planning/data/meal_plan_repository.dart:777-790) archives every other local plan of the week whenever it applies a confirmed plan. Its comment says it mirrors `confirm_meal_plan`, but it runs on every pull (meal_plan_controller.dart:60, :301, :329, home_service.dart:95), so a draft started after the week's confirm is archived on the phone while the server keeps it a draft. 173cebb2 (the plan 86-002 named) is now archived on both sides. On screen, Previous plans lists two unlabelled "Sep 20 – Sep 26" rows (1 meal, 5 meals) with no Draft mark (runs/120/10-previous-plans.png); not opened.

**Evidence.**
- runs/120/local-plans-02-settled.txt (50390c90 archived locally)
- runs/120/db-01-test-week0920-plans.txt (dev: 50390c90 draft)
- runs/120/10-previous-plans.png

**Decision quote.**
> 

**Triage.**

