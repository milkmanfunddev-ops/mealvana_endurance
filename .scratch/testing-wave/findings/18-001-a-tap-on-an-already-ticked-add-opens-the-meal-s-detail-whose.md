# 18-001 · A tap on an already-ticked Add opens the meal's detail, whose Add to plan adds it again and doubles the servings (4 to 8) with no warning

- kind: bug
- status: closed
- ticket: 18
- run: w16-20260924T2100Z
- screen: Browse meals (from the Vana planning chat)
- decision: 

**Steps.**
1. Sign in as test@test.com. Food > Plan > "Ask Vana anything" > Conversations > Meal plans > open the Sep 22 9:24 PM "This week's plan" (conversation 0401b3d8).
2. Composer plus > Browse meals. Filters > Recipes (or Recipes > See all).
3. Tap "+" on Sweet rice cake with jam: toast "Added to your plan", the button turns into a tick.
4. Tap the ticked button again.
5. On the detail that opens, scroll down and tap Add to plan.

**Expected.**
A ticked meal is already in the draft: tapping the tick does nothing, or says it is already added. The detail opened from Browse should not offer a plain "Add to plan" for a meal already in the draft, or should say it will add more servings.

**Actual.**
Step 4 opened Sweet rice cake's meal detail (the tap on the disabled tick falls through to the card, whose body opens the detail). The detail offered Add to plan as if nothing had been added. Tapping it showed the same "Added to your plan" toast and the server raised the draft's row from 4 to 8 servings (plan_meals servings 8, servings_left 8), and rebuilt the list for 8 servings (16 tbsp strawberry jam, 1.6 kg rice, 8 eggs). Nothing on screen said the meal was already in the plan or that its servings were doubled. Cause, from the code: MealAddButton gets onTap null once added, so the card's own tap handler (open detail) takes the touch; the detail's Add to plan calls pick_meals, and plan.ts addMeal adds the servings to an existing row.

**Evidence.**
- runs/18/32-add-tap-2s.png: card ticked after the first Add, toast shown.
- runs/18/33-second-tap-on-ticked.png: the second tap on the tick opened Sweet rice cake's detail.
- runs/18/34-detail-add-to-plan-0s.png: Add to plan on that detail, spinning.
- runs/18/35-after-detail-add.png: back on Browse, the same toast again.
- runs/18/db-01-after-card-add.txt: plan_meals servings 4 after the first Add.
- runs/18/db-02-after-ticked-card-detail-add.txt: servings 8 after the detail's Add to plan.
- runs/18/edge-function_logs.txt: pick_meals at 16:09:25 and 16:10:21 CDT.

**Decision quote.**
> 

**Triage.**
Fix ticket 34 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): pass, evidence in runs/88/verdicts.md. Side problems filed as 88-007.
