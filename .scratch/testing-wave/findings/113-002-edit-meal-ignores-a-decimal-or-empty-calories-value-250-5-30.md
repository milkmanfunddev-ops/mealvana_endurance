# 113-002 · Edit Meal ignores a decimal or empty Calories value: 250.5, 300.5 and an empty field all keep the old calories, and it still says Meal updated

- kind: bug
- status: triaged
- ticket: 113
- run: w40-20260926T1051Z
- screen: Edit Meal
- decision: 

**Steps.**
1. Follow-ups 27-005 (decimal and empty values) and 25-005 (can the 250.5 kcal row be corrected). test@test.com.
2. Timeline → ⋯ → Edit food on "W40-113 Decimal kcal" (251 kcal). Calories 250.5 → Save changes (11:09:59Z). Again with 300.5 (11:10:27Z). Again with the field emptied (11:10:46Z).
3. Sep 24 → ⋯ → Edit food on the old row a61f94fd "W14-25 Decimal kcal" (calories null). Calories 250.5 → Save changes (11:21:09Z).
4. SELECT calories after each save.

**Expected.**
The Manual tab now rounds 250.5 to 251 (fix 41), so Edit Meal should save 251 (301 for 300.5); an empty field should clear calories to unknown, or the form should refuse it. Either way the athlete should not be told "Meal updated" for a value that was dropped.

**Actual.**
Every save shows "Meal updated" and bumps updated_at, but calories never change: 250.5 and 300.5 leave 251, the empty field leaves 251, and on the old row 250.5 leaves null (timeline still "0 kcal"). Typing the whole number 251 does save (11:21:36Z), which is how the old row was corrected. Cause (code read): `edit_meal_log_screen.dart` `_buildUpdatedLog` still parses `calories: int.tryParse(_calCtrl.text)`, which is null for "250.5" and for "", and `copyWith(calories: null)` keeps the old value. Fix 41 changed the Manual tab and Build a Meal's Manual form (`parseCaloriesInput`) but not Edit Meal. The field's filter accepts decimals.

**Evidence.**
- runs/113/64-edit-meal-250-5.png (250.5 typed)
- runs/113/65-edit-meal-300-5.png (300.5 typed)
- runs/113/66-edit-meal-empty-kcal.png (field empty)
- runs/113/db-after-edit-250-5.txt (calories 251 after each of the three saves)
- runs/113/db-old-row-correct.txt (old row: null after 250.5, 251 after typing 251)

**Decision quote.**
> 

**Triage.**

Fix ticket 136, Build a Meal, saved meals, Manual and Edit (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
