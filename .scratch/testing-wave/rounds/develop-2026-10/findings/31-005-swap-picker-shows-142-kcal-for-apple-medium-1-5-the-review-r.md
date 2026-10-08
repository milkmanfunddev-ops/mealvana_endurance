# 31-005 · Swap picker shows 142 kcal for Apple (medium) × 1.5, the Review row it creates shows 143 kcal

- kind: bug
- status: open
- ticket: 31
- run: w3-20261008T1256Z
- screen: Review & Log (food swap picker)
- decision: 

**Steps.**
1. On Review & Log, swipe the toast row right to left to swap it.
2. In the picker (titled "Add Food") pick Apple (medium), tap + once (1.0 -> 1.5).
3. ADD FOOD.

**Expected.**
The calories the picker shows are the calories the item gets.

**Actual.**
The picker reads 142 kcal (95 × 1.5 = 142.5) and the new Review row reads "Apple (medium) · 1.5 servings · 143 kcal". The swap path rounds with `.round()` (meal_review_screen.dart:105, from code) while the picker shows a truncated or differently rounded figure. The quantity folded into the portion text ("1.5 servings") is known, ticket 38, and not part of this Finding.

**Evidence.**
- runs/31/24-swap-apple-qty2.png — picker at 1.5: 142 kcal
- runs/31/25-review-after-swap.png — row: 143 kcal

**Decision quote.**
> 

**Triage.**

