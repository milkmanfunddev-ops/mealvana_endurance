# 11 Fuel Log (Nutrition Diary)

The 2nd bottom-nav tab — Nutrition Diary / daily macro tracking.

---

## nutrition_diary_empty
**Screenshot:** `screenshots/01_nutrition_diary.png`
**Reached by:** Bottom nav → 2nd icon (fork/utensil) before any activity exists for the day.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Calendar         | Same week strip + month label      | top                | (shared `calendar.*` keys)              |
| Section heading  | "Nutrition Diary"                  | (16, 540, 220x26)  | `nutrition_diary.heading`               |
| Card (big number)| "2,366 cal" + "Daily Total"        | (32, 610, 366x180) | `nutrition_diary.daily_total_card`      |
| Macro pip        | "308g Carbs"                       | row inside card    | `nutrition_diary.carbs_label`           |
| Macro pip        | "108g Protein"                     | row inside card    | `nutrition_diary.protein_label`         |
| Macro pip        | "78g Fat"                          | row inside card    | `nutrition_diary.fat_label`             |
| Section          | "Energy Breakdown"                 | inside card        | `nutrition_diary.breakdown_section`     |
| Row              | "Resting" / "1,707 cal"            | inside card        | `nutrition_diary.resting_row`           |
| Row              | "Daily activity" / "427 cal"       | inside card        | `nutrition_diary.daily_activity_row`    |
| Row              | "Total burn (TDEE)" / "2,371 cal"  | inside card        | `nutrition_diary.tdee_row`              |
| Toggle/Section   | "Weekly overview" (expandable)     | (32, 810, 200x30)  | `nutrition_diary.weekly_overview_toggle`|

---

## nutrition_diary_with_workout
**Screenshot:** `screenshots/04_nutrition_diary_with_workout.png`
**Reached by:** Bottom nav → 2nd icon after an activity is saved for today.

### Additional rows
- Energy Breakdown now adds **"Workout / 1,616 cal"** between Daily activity and Total burn.
- Total burn updates to **"4,151 cal"** to include workout burn.

Proposed key: `nutrition_diary.workout_row`.

---

## weekly_chart
**Screenshot:** `screenshots/03_weekly_chart.png`
**Reached by:** Tap **"Weekly overview"** to expand.

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Chart            | Multi-series line chart            | `weekly_chart.chart`                    |
| Button (icon)    | Info "i" (top-right of chart)      | `weekly_chart.info_button`              |
| Legend pip       | "Cal" (white dot)                  | `weekly_chart.legend_cal`               |
| Legend pip       | "Carbs" (teal)                     | `weekly_chart.legend_carbs`             |
| Legend pip       | "Protein" (orange)                 | `weekly_chart.legend_protein`           |
| Legend pip       | "Fat" (pink)                       | `weekly_chart.legend_fat`               |

### Notes
- X-axis: S/M/T/W/T/F/F/S (last 7 days). The original double "F/F" is suspicious; integer-only X labels were added in a prior fix (commit `5a10fbf`) — could be a separate bug.
- Y-axis: integer-only labels (per commit `5a10fbf` fix).
- The "i" info button shows a tooltip describing the metric (not exercised).
