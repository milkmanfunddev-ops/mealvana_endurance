# 50-002 · Follow-up: ticket 44 / 30-004 workout-day protein 1.6 g/kg can only be checked in a fresh signup's daily-plan preview, not signed in

- kind: followup-test
- status: open
- ticket: 50
- run: w5-20261008T1720Z
- screen: Onboarding → Your daily plan (daily-plan preview); Settings → Nutrition Targets
- decision: 

**Steps.**
1. On a fresh signup (own account, ticket that signs up): 62 kg, Running + Cycling, no body fat, no imports.
2. Reach the daily-plan preview in onboarding; open the Workout day tab; read the macros card's protein g/kg.
3. Repeat with a body fat value entered (baseline then comes from lean mass, so 1.6 is not expected).

**Expected.**
Workout day protein 1.6 g/kg (99 g at 62 kg; rest and carb-load days 87 g), per ticket 44's fix.

**Actual.**
Not run in this ticket. Signed in, no route reaches the preview: Settings → Nutrition Targets edits only
pre/during/post fuel overrides (Carbs/Protein/Fat/Sodium/Fluids per window, no daily protein), and opening
`/onboarding` signed in would write onboarding drafts on the shared test account, so it was not tried.

**Evidence.**
- runs/50/h01-nutrition-targets.png the signed-in Nutrition Targets screen (no daily protein)

**Decision quote.**
> 

**Triage.**

