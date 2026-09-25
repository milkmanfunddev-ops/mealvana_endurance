# 89-012 · With no plan this week the Plan tab has no menu, so Previous plans and Use this plan again cannot be opened

- kind: bug
- status: open
- ticket: 89
- run: w29-20260925T1950Z
- screen: Food (Plan sub-tab)
- decision: 

**Steps.**
1. A new account (lee+e2e-89-20260925T2024Z) with no plan this week: Food > Plan.
2. Look for the ⋮ that holds Previous plans.

**Expected.**
An athlete can reach Previous plans, and so Use this plan again (mp-675), whenever they have earlier plans, including the start of a new week before a plan exists.

**Actual.**
The Plan tab shows only "No plan yet. Vana will build one with you ..." with Add meal and New meal plan; `PlanOverflowMenu` is built only when the week's plan has meals (plan_tab.dart). Previous plans has no other entry point. So at the start of each week (every Sunday for test@test.com), or after Delete plan, earlier plans cannot be opened or used again until a new plan is started, which is the moment Use this plan again is for. 17-006 step 4 (a Plan tab with no current plan) could not be run for this reason. Product question: where should Previous plans live when the week has no plan?

**Evidence.**
- runs/89/91-throwaway-plan-tab.png: the Plan tab with no plan and no menu.

**Decision quote.**
> 

**Triage.**
