# 27-005 · Edit Meal screen: untried leave-with-unsaved-changes, decimal and empty values, meal type and time eaten changes, kill on the screen

- kind: followup-test
- status: triaged
- ticket: 27
- run: w15-20260924T2039Z
- screen: Edit Meal
- decision: 

**Steps.**
1. Timeline → ⋯ → Edit food on a manual row (no items): Edit Meal shows Scan a photo, name, meal type, time eaten, kcal, carbs, protein, fat (prefilled "60.0" style), Add more detail, Save changes.

**Expected.**
Paths not run in ticket 27:
- Change a field and tap Back: the leave dialog (discard / save / keep editing) and each choice's result on the row.
- Enter 250.5 kcal (25-001 saves null on the Manual tab; does Edit Meal do the same?), empty calories, empty name, 0.
- Change meal type, and change Time eaten to yesterday or across midnight: does the row move day (log_date) and both days' totals follow?
- Add more detail: sodium and notes saved.
- Background or kill the app on Edit Meal: the route extra has no codec (console GoRouter warning at 15:45:01 local), so restoring may lose the meal being edited.
- Scan a photo (AI; spend COST logging first).

**Actual.**
Not run. The run changed name, kcal, carbs and protein and saved; the row and totals matched.

**Evidence.**
- runs/27/17-edit-meal-screen.png
- runs/27/18-edit-meal-filled.png
- runs/27/console-redacted.log (GoRouter "extra ... without a codec" on /meal-log/edit, 15:45:01 local)

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
