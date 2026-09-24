# 25-001 · Manual log accepts 250.5 kcal, shows Meal logged!, and saves calories as null (timeline reads 0 kcal)

- kind: bug
- status: open
- ticket: 25
- run: w14-20260924T2015Z
- screen: Log a Meal → Manual tab
- decision: 

**Steps.**
1. Timeline → + Add Food → Log a Meal → Manual.
2. Meal name "W14-25 Decimal kcal", Meal type left on Any time, Calories 250.5, Carbs 30.2, Protein 12.25, Fat 8.4.
3. Save (20:19:12–20:19:14Z). The snackbar says "Meal logged!".
4. Read the new row from dev meal_logs; open Timeline → Meals.

**Expected.**
The ticket: saved numbers equal what was entered. The field takes a decimal point (decimal keyboard and input filter), so the row should hold 250.5 kcal (or 251 if calories are whole numbers), or the form should refuse the value before saving.

**Actual.**
Row a61f94fd (created 20:19:13Z) has `calories: null`. Carbs 30.2, protein 12.25 and fat 8.4 are saved as entered. The timeline shows the meal as "0 kcal · 30C · 12P · 8F", so 250.5 kcal disappear from the day's total without any warning. The code parses calories with `int.tryParse` (manual_log_form.dart `_submit`), which returns null for "250.5", while the field's filter (`^\d*\.?\d*`) accepts decimals. Not tried on the device: the Build a Meal Manual form (manual_component_form.dart `_addToMeal`) parses calories the same way, so it probably drops a decimal kcal too.

**Evidence.**
- runs/25/09-decimal-filled.png (fields as entered)
- runs/25/10-decimal-saved.png ("Meal logged!")
- runs/25/24-timeline-meals.png (row reads 0 kcal)
- runs/25/db-meal-logs.txt (row a61f94fd, comparison line "decimal")

**Decision quote.**
> 

**Triage.**
