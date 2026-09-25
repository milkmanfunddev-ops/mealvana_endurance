# 03-009 · A long-run carb target edited on the plan reveal is not saved: after email signup nutrition_target_overrides is null

- kind: bug
- status: triaged
- ticket: 03
- run: w3-20260923T1942Z
- screen: Plan Reveal Onboarding
- decision: 

**Steps.**
1. Fresh install. Onboarding: Running, a goal, "I don't use training plan apps", personal info,
   body composition, gut training high, sweat heavy.
2. Plan reveal: tap the long-run pencil, drag the slider (the app logged
   `plan_target_edited {field: long_run_carb_gph, from: 70, to: 95}`), close it, Continue.
3. Daily preview → Save My Plan → sign up by email (lee+e2e-signup-1790216303921@…, user
   b8f90d7b-…). The paywall shows.
4. Read the new account's `public.users` row.

**Expected.**
`nutrition_target_overrides` carries the edited long-run carb rate (`duringRun`), as the other
onboarding answers are carried (the signup flow's own assertion: "the edited long-RUN carb target
must survive signup").

**Actual.**
`nutrition_target_overrides` is null for both accounts this run created, while gut training
(high), sweat rate (heavy), `onboarding_completed` and the survey row all arrived. The edit is
dropped between the plan reveal and the uploaded profile. onboarding_signup_flow_test fails on
this assertion (and then runs out its 12-minute timeout, the known cost of a failed Patrol test).

**Evidence.**
- runs/03/device-clean-c3.log, `[ANALYTICS] plan_target_edited {field: long_run_carb_gph, from: 70, to: 95}`
- runs/03/db-e2e-accounts.txt (`has_overrides: false` for 5d1e75f7-… and b8f90d7b-…)
- runs/03/patrol-clean-c3.log (steps 1 to 35 pass, then the test fails)

**Decision quote.**
> 

**Triage.**
Fix ticket 40 (Lee, 2026-09-25). Closed by the retest after it merges.
