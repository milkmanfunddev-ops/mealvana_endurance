# 89-014 · Team review rows are saved with app_version empty

- kind: bug
- status: open
- ticket: 89
- run: w29-20260925T1950Z
- screen: Meal detail (Team review)
- decision: 

**Steps.**
1. Admin (test@test.com), meal detail > Team review > Good recipe, a why, Send review (20:19:18Z).
2. Read the new `meal_reviews` row.

**Expected.**
`app_version` holds the build that sent the review (the column exists so reviews can be tied to a build).

**Actual.**
Row 8861acf0: is_good true, why "testing-wave 89 check, ignore", app_version NULL. Build 1.27.1 (4), commit e3367d2c.

**Evidence.**
- runs/89/73-18-010-review-sent.png: the box after sending.
- runs/89/notes.md: 18-010 section, the meal_reviews row.

**Decision quote.**
> 

**Triage.**
