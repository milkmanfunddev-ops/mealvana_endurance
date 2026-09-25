# 18-003 · Reopened Browse shows meals already in the draft with a plain plus, so each tap adds four more servings of the same meal

- kind: bug
- status: triaged
- ticket: 18
- run: w16-20260924T2100Z
- screen: Browse meals
- decision: 

**Steps.**
1. In planning conversation 0401b3d8, plus > Browse meals; add Sweet rice cake with jam and Quinoa porridge (both tick).
2. Done: the chat's plan bar says "Your plan · 2 meals".
3. Plus > Browse meals again.

**Expected.**
Meals already in this conversation's draft show ticked when Browse opens (mp-236: "Every card carries a tick that picks into the draft"), so the athlete sees what is already in the plan.

**Actual.**
Both meals sit at the top of Recents with a plain "+" ("Add to plan"), as if not added. The ticks live only in the screen's own state (VanaBrowseScreen._added), so every visit starts empty and each "+" on an already-planned meal adds 4 more servings to its row (plan.ts addMeal). The filters also reset on reopen. Not tapped a second time here; 18-001 shows the servings being added on top.

**Evidence.**
- runs/18/37-after-quinoa-detail-add.png: both meals ticked before Done.
- runs/18/39-chat-after-done-5s.png: plan bar "Your plan · 2 meals".
- runs/18/40-browse-reopened.png: the same two meals in Recents with plain "+".

**Decision quote.**
> 

**Triage.**
Fix ticket 34 (Lee, 2026-09-25). Closed by the retest after it merges.
