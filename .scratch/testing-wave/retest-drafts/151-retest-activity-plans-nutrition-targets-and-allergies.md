# 151: Retest: a new activity's plan, Nutrition Targets overrides, and allergies in the Formula Library

**Status:** ready-for-agent
**Blocked by:** 137, 138.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix tickets 137 and 138 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`), on an account of its own so overrides and allergies never touch test@test.com. It re-runs each Finding's steps against the fixes and runs the folded follow-ups. The Activity detail screen keeps its look and copy, so only numbers and navigation are judged. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** account D, new, `lee+e2e-151-<UTC>`, sport Running (and Cycling if onboarding allows both, for check 5). Buy **Annual** (1-hour periods: the Monthly's 5-minute period brought the paywall mid-check in 116-014). App data cleared. Checks run in order: the activity from check 1 is used by checks 2-5 and 7.

**Shared account:** none.

**COST:** none. `generate-nutrition-plan-v3` is algorithmic, not an AI call.

## Checks

1. **Back from a new activity lands on the Timeline (116-011).** Timeline > + Add Activity > Running, defaults (12 mi Run, a future day inside the forecast window) > Generate Plan > Create Plan on Adjust Your Macros. On the new activity tap Back once. *Pass:* the Timeline, not Adjust Your Macros or the form. *Verify:* screenshots, console route lines.
2. **The during template passes its own check (117-016).** Read `generate-nutrition-plan-v3` logs for check 1's minute (`scripts/edge_logs.sh`). *Pass:* the template plan is used (no "fails its own carb check … falling back to the rule solver"), or the log says why no template fits. *Verify:* edge-log extract.
3. **By Hour counts sip-throughout items (116-005).** The activity > DURING > By Hour. *Pass:* Hour 1 and Hour 2 carry their share of the sip item's carbs and sodium (not 0 g / 0 mg), and the hours sum to the DURING total. *Verify:* screenshot, numbers in notes.
4. **Clearing a during override re-plans (116-003).** Settings > Nutrition Targets: During Run carbs 50 > Save. Open the activity (DURING reflects 50 g/h). Clear During Run > Save. Reopen. *Pass:* the stored plan is flagged `needs_nutrition_refresh` and re-plans without the override, and DURING returns to the calculated value. 137 notes say the info icon is not kept and `StalePlanWarning` explains instead: judge that. *Verify:* SELECT `users.nutrition_target_overrides`, `activities` (needs_nutrition_refresh, updated_at) and the plan's during figure, screenshots.
5. **One sport cleared, Reset All, typed then cleared (116-017, 119-015).** Overrides on Run and Bike > clear only During Run > Save: the bike value survives. Reset All to Defaults: the DB holds null and every field reads Auto. Pre-Activity Carbs 60 > Save, then clear it back to Auto > Save. *Pass:* each SELECT matches the screen after each save. A legacy `during` key is not re-written. *Verify:* SELECT `nutrition_target_overrides` after every save.
6. **First open of a stored plan writes nothing (116-007).** A second activity that has a stored plan and has not been opened on this install (create it, then clear the app and sign in again). Note `activities.updated_at` and the plan's `updatedAt`. Open it, wait 30 s, tap the info icon, dismiss it, tap By Hour, SELECT after each. *Pass:* no write while the plan is unchanged. *Verify:* SELECT before and after each step.
7. **Allergies reach the server (116-002).** Settings > Diet, Allergies & Formulas > Allergies: Peanuts > Save. Then add Gluten > Save. *Pass:* `users.allergies` holds each within seconds online. Offline (`netcut on`), a change is sent once back online (138 item 13). *Verify:* SELECT allergies, updated_at after each save.
8. **Peanut matches Peanuts (116-001).** Formula Library > Before. The Peanuts filter hides "Bagel + PB + Jam" (allergens {Gluten, Peanut}), and pinning it warns of the conflict. *Pass:* both. *Verify:* screen, SELECT `formula_pins`.
9. **Omnivore is not an allergen chip (116-013).** Formula Library > More filters. *Pass:* no Omnivore under HIDE FORMULAS WITH, and diets (if shown) sit in their own labelled row. *Verify:* screenshot.
10. **A pinned conflicted formula (116-014).** With Gluten set, pin a gluten formula with Pin anyway. *Pass:* the card shows the persistent conflict label and the pin glyph's conflict dot. Expand, Keep pin, then Unpin all work. *Verify:* screen, SELECT `formula_pins` after each step.

**Findings:** 116-011, 117-016, 116-005, 116-003, 116-002, 116-001, 116-013; follow-ups 116-017, 119-015, 116-007, 116-014.

**Decisions:** Lee's rulings in `triage-20260926.md` (117-016, the Activity detail standing rule). `docs/ssot/vectors/` went green in 137.

**Touches:** account D only: activities and their plans, `nutrition_target_overrides`, allergies, formula pins. D is deleted at the end.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/151/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Account D is deleted through the app at the end.

Next: /implement-lee testing-wave
