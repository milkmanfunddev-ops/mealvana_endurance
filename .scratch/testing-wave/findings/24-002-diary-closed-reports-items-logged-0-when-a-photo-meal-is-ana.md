# 24-002 · diary_closed reports items_logged 0 when a photo meal is analyzed and then logged from Review & Log

- kind: bug
- status: open
- ticket: 24
- run: w14-20260924T2015Z
- screen: Log a Meal (Describe, photo) and Review & Log
- decision: 

**Steps.**
1. + Add Food opens Log a Meal on Describe; Gallery, pick a photo, Analyze.
2. The app pushes /meal-log/review; on Review & Log, tap Log this meal.
3. Read the analytics lines in the console.

**Expected.**
The diary session that ends in a logged meal reports it: `items_logged` 1 on `diary_closed` (or
`diary_closed` fires after the save).

**Actual.**
`diary_closed {duration_sec: 58, items_logged: 0, log_date: 2026-09-24}` fires at 15:18:45 local, as the
app pushes Review & Log, before the meal is saved; `meal_logged {source: photo}` follows at 15:19:18.
The code says `items_logged: 0` "is the signal that the diary looked but didn't land"
(`log_meal_screen.dart` L225), so every photo or describe log that goes through Review & Log reads as an
abandoned diary. The meal itself saved correctly.

**Evidence.**
- runs/24/console-redacted.log: lines with `[ANALYTICS] meal_ai_completed`, `diary_closed` and `meal_logged` (15:18:44-15:19:18 local).
- runs/24/11-after-save.png: the meal on the timeline after the save.

**Decision quote.**
> 

**Triage.**
