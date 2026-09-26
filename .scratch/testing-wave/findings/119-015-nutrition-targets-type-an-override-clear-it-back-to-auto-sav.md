# 119-015 · Nutrition Targets: type an override, clear it back to Auto, save, check the override is gone

- kind: followup-test
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Nutrition Targets
- decision: 

**Steps.**
1. On a throwaway account, Settings > Nutrition Targets: type 60 in Pre-Activity Carbs, save.
2. Reopen, clear it back to empty (Auto), save.
3. Read users.nutrition_target_overrides by SQL after each save.

**Expected.**
The first save stores the override; the second removes it (the controller's `clearNutritionTargetOverrides` path).

**Actual.**
Not run.

**Evidence.**
- runs/119/25-nutrition-targets.png: the screen

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
