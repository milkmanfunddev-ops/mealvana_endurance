# 89-009 · Meal detail heart shows empty again on reopen of a meal already saved

- kind: bug
- status: open
- ticket: 89
- run: w29-20260925T1950Z
- screen: Meal detail (opened from Browse)
- decision: 

**Steps.**
1. test@test.com. Browse > Filters > Dinner > open "Quinoa, mixed veg & walnuts" (AD-015).
2. Tap the heart (Save to mine): "Saved to My Foods", heart fills, saved_meals 09f59fb0.
3. Tap the filled heart again. Then Back, reopen the same card, look at the heart and tap it.

**Expected.**
The heart shows the meal is saved every time it opens; a second tap either unsaves it or says it is already saved.

**Actual.**
Step 3: the filled heart does nothing (disabled once saved; there is no unsave). After Back and reopen the heart is empty again (`_SaveToMineButton._saved` starts false on every open); tapping it shows the save again, and the server dedups (still one saved_meals row). An athlete cannot tell from the detail that a meal is already in My Foods, and cannot take it out from here.

**Evidence.**
- runs/89/63-18-010-heart-tapped.png: saved, heart filled, toast.
- runs/89/66-18-010-detail-reopened.png: reopened, heart empty.
- runs/89/67-18-010-heart-second-save.png: filled again after the second save.
- runs/89/notes.md: 18-010 section, saved_meals rows.

**Decision quote.**
> 

**Triage.**
