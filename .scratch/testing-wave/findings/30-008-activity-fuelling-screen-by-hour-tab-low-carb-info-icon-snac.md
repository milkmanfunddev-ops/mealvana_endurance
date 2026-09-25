# 30-008 · Activity fuelling screen: By Hour tab, low-carb info icon, snack expander, After targets, a session with no stored plan

- kind: followup-test
- status: triaged
- ticket: 30
- run: w10-20260924T1615Z
- screen: Activity detail (fuelling plan)
- decision: 

**Steps.**
1. DURING "By Hour" tab against the stored per-hour rates.
2. The info icon next to a below-band carbs figure (tapping it in this run hit a food row after the list scrolled; retry on a still screen).
3. The Pre-Workout Snack expander (">"), and the food rows' expanded view (quantity stepper, Remove food item) without changing anything, then Back: no save prompt, stored plan unchanged.
4. AFTER shows foods only, no targets, while the stored plan has After carbs 84 g, protein 29 g, fluids 1296 mL, sodium 357 mg. Check whether targets belong there.
5. Open a session with no stored plan (today's "Easy" 05:32) and see whether opening it generates and writes `nutrition_plan_data` (this run avoided it: read only).
6. Pin formulas you love, Save as Routine, Edit: open and cancel.

**Expected.**
Every number on the screen maps to a stored field or to the sum of the stored foods, and opening the screen writes nothing.

**Evidence.**
- runs/30/10-12mi-run-during-after.png
- runs/30/11-12mi-run-water-expanded.png
- runs/30/db-fuel-plans-summary.txt

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 116 when 92 was split (Lee, 2026-09-25).
