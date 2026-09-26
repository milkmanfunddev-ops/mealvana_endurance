# 116-001 · A Peanuts allergy never matches the formula allergen Peanut, so pinning Bagel + PB + Jam gives no warning and the Peanuts filter hides nothing

- kind: bug
- status: triaged
- ticket: 116
- run: w32-20260925T2220Z
- screen: Formula Library (Before)
- decision: 

**Steps.**
1. New account lee+e2e-116-20260925T2244Z (Test Store monthly). Settings > Diet, Allergies & Formulas > Allergies: tick Peanuts, Save (22:48:13Z; console `allergies_saved {allergies: [peanuts]}`).
2. Formula Library > Before. Find "Bagel + PB + Jam" (pre_workout_templates.allergens = {Gluten, Peanut}). Tap its pin.
3. Control: add Gluten to the allergies, clear the Gluten and Peanuts chips in More filters, pin "Bagel + Cream Cheese" ({Gluten, Dairy}).
Retest of Finding 03-005, run by hand on this run's own account (the wave lead's ruling), not the Patrol account.

**Expected.**
With a Peanuts allergy on the profile, the Peanuts chip under More filters > HIDE FORMULAS WITH hides every formula whose allergens include peanut, and pinning one raises the inline allergy warning (Choose another / Pin anyway) first (formula-pin-surface.md FP-4a).

**Actual.**
Step 2: Bagel + PB + Jam is listed although More filters shows Peanuts selected under HIDE FORMULAS WITH, and the pin goes straight through: no warning, no label; `formula_pins` row written at 22:48:59Z. Step 3 (Gluten): the library hid every gluten formula at once, and pinning Bagel + Cream Cheese raised "This formula contains gluten, which you've listed as an allergy…" with Choose another / Pin anyway. So the conflict path works, but not for peanuts. The data disagree on the spelling: the template catalog's only peanut value is "Peanut" (distinct allergens in pre_workout_templates: Dairy, Eggs, Gluten, Peanut), while the app's allergy value is "peanuts" (`Allergy.dbValue`). Both `pinConflictLabelRequired` (lib/features/nutrition_plan/domain/selection_precedence.dart) and the library filter (formula_library_controller.dart:152) compare lower-cased strings exactly, so "peanut" never equals "peanuts". The same check drives plan selection, so a pinned peanut formula would also never carry its conflict label. 03-005's retest fails on this.

**Evidence.**
- runs/116/75-pin-bagel-pb.png (Bagel + PB + Jam pinned, no warning)
- runs/116/78-more-filters.png (Peanuts selected under HIDE FORMULAS WITH)
- runs/116/80-pin-gluten-formula.png (the gluten warning, for comparison)
- runs/116/db-newacct-formula-pins.json (the pin row written without a warning)
- runs/116/console-excerpt-allergies.txt (allergies_saved [peanuts], then [peanuts, gluten])
- runs/116/notes.md (New account section)

**Decision quote.**
> 

**Triage.**

Fix ticket 138, Settings, connections, allergies, Garmin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
