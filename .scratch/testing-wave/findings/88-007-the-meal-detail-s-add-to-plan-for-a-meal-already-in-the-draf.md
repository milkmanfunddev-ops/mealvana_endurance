# 88-007 · The meal detail's Add to plan for a meal already in the draft says Added to your plan but adds nothing

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Meal detail (from Browse meals)
- decision: 

**Steps.**
1. Retest of 18-001. Conversation `0401b3d8` (draft 173cebb2 holds Sweet rice cake with jam x8). Plus > Browse meals: Sweet rice cake shows "In your plan".
2. Tap the tick: nothing happens (fixed). Tap the card body: its detail opens.
3. Scroll down and tap "+ Add to plan" (20:03:58Z).

**Expected.**
The detail says the meal is already in the plan (or offers more servings on purpose); nothing claims an add that did not happen.

**Actual.**
The detail offers a plain "+ Add to plan". Tapping it spins, returns to Browse and shows the toast "Added to your plan", while plan_meals keeps Sweet rice cake at 8 servings and the list is not touched (the servings no longer double, which was 18-001's bug). The toast tells the athlete something happened that didn't.

**Evidence.**
- runs/88/40-18-001-detail-bottom.png: "+ Add to plan" on a planned meal.
- runs/88/42-18-001-detail-add-4s.png: "Added to your plan".
- runs/88/db-07-18-001-173cebb2.txt: servings 8 before and after.

**Decision quote.**
> 

**Triage.**

Fix ticket 128 (Lee, 2026-09-25): the detail shows "In your plan" and no Add. Closed by the retest after it merges.
