# 112-005 · The trash icon on a Saved meal deletes it at once, with no confirm and no undo

- kind: bug
- status: open
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Recent → Saved meals)
- decision: 

**Steps.**
1. Retest of follow-up 26-006 step 3. Make a throwaway saved meal: Build a meal → Manual item "E2E 112 throwaway" 100 kcal → meal name "E2E 112 throwaway" → tick "Also save as a favorite" → Log meal (23:45:28Z; saved_meals 85c22213).
2. Log a Meal → Recent. Tap the red trash icon on the "E2E 112 throwaway" Saved row (23:46:08Z).
3. Look at the screen 1 s later; read saved_meals.

**Expected.**
26-006: the app asks before deleting, or offers undo. The icon sits about 30 px from the row's + button, so a slip deletes a favorite.

**Actual.**
The row vanished at once. No dialog, no snackbar, no undo (76-after-trash-tap.png at 23:46:09Z). The server row got `is_deleted true` at 23:46:08.585Z. The two real saved meals (fd993bbb, 09f59fb0) were not touched.

**Evidence.**
- runs/112/75-before-trash.png
- runs/112/76-after-trash-tap.png
- runs/112/db-run-rows.txt (saved_meals)

**Decision quote.**
> 

**Triage.**
