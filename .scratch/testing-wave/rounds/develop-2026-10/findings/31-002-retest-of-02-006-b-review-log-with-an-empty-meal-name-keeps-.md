# 31-002 · Retest of 02-006 (b): Review & Log with an empty meal name keeps Log this meal enabled and the tap does nothing, silently

- kind: bug
- status: open
- ticket: 31
- run: w3-20261008T1256Z
- screen: Review & Log
- decision: 

**Steps.**
1. Describe "two scrambled eggs, a slice of whole wheat toast with butter, a banana", Analyze (spend 1).
2. On Review & Log, delete the whole meal name.
3. Scroll down and tap Log this meal (13:05:03Z).

**Expected.**
Log this meal is disabled while the name is empty, or the tap says why (a field error or MealvanaSnackbar) — 02-006: "an empty name says why it will not log".

**Actual.**
The button stays orange and enabled; the tap does nothing: no message, no navigation, no row (SQL 0 rows for this run at that time). `_logMeal` returns early on `name.isEmpty` (meal_review_screen.dart:118, from code) with no feedback.

**Evidence.**
- runs/31/20-name-cleared.png — empty name field
- runs/31/21-review-scrolled-empty-name.png — Log this meal enabled with the name empty
- runs/31/22-log-empty-name-tap.png — screen unchanged after the tap
- runs/31/notes.md — 02-006 (b) entry

**Decision quote.**
> 

**Triage.**

