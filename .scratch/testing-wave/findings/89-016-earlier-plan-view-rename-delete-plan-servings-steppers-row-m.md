# 89-016 · Earlier plan view: Rename, Delete plan, servings steppers, row menu, and Confirm on a Use this plan again copy

- kind: followup-test
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Earlier plan view
- decision: 

**Steps.**
1. Open an earlier plan (now editable, mp-675): change servings with the stepper, use a row's ⋮, Rename (empty, 60+ characters), Delete plan, and check each against `meal_plans` / `plan_meals`.
2. Use this plan again, then Confirm on the copy: the week's plan is replaced, the copy's list becomes the Shopping tab's list, and Previous plans lists the replaced plan.
3. Does editing an archived plan rebuild its list (syncPlanList keeps once-confirmed plans editable), and does that list show in Previous lists?
4. ×N on an earlier plan: servings or servings_left, once a plan has meals logged from it.

**Expected.**
Each edit lands on the plan shown; confirm replaces this week's plan the way any confirm does (mp-241, mp-675).

**Actual.**
Not run (followup).

**Evidence.**
- runs/89/40-earlier-plan-sep13-retry.png: the view with steppers and row menus.
- runs/89/42-earlier-plan-options.png: Rename, Use this plan again, Delete plan.

**Decision quote.**
> 

**Triage.**

Picked for the retests of fix tickets 126-132 (Lee, 2026-09-25); placed when those retest tickets are written.
