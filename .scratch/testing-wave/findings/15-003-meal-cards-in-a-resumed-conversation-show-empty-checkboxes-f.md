# 15-003 · Meal cards in a resumed conversation show empty checkboxes for meals that are in the conversation's plan

- kind: bug
- status: triaged
- ticket: 15
- run: w12-20260924T1712Z
- screen: Vana chat (meal planning), opened from Conversations
- decision: 

**Steps.**
1. Conversations → Meal plans → Sep 22, 7:08 AM (`ebac747d`); scroll to Vana's suggestion cards.
2. Back; open Sep 16, 1:48 PM (`1a24f2bf`); look at the last turn's cards.

**Expected.**
A card for a meal that is in this conversation's plan shows as picked (checked), as it did when it was picked, so the athlete can tell from the history what went into the plan.

**Actual.**
Every card shows an empty checkbox. In `ebac747d`, "Injera with shiro wot" and "Rice, black beans, guac & hot sauce" are in its plan `15b6b4f4` (plan_meals D-024 and L-011) and show empty boxes. In `1a24f2bf`, "Tofu, quinoa, spinach & chard bowl" is in the confirmed plan `f2c0bc78` (AL-176, 3 servings) and shows an empty box while the plan bar above says "6 meals · Plan confirmed". Ticket 16 saw the same on `d8efbdb3` (16-010, step 3). Two plan states here (archived and confirmed), so it is not only an archived-plan case.

**Evidence.**
- runs/15/13-ebac747d-scroll-3.png — Injera card, empty box.
- runs/15/12-ebac747d-scroll-2.png — Rice, black beans, guac & hot sauce card, empty box.
- runs/15/19-1a24f2bf-open.png — Tofu, quinoa, spinach & chard card, empty box, plan bar "Plan confirmed".
- runs/15/db-before.txt — plan_meals of 15b6b4f4 and f2c0bc78.

**Decision quote.**
> 

**Triage.**
Fix ticket 48 (Lee, 2026-09-25). Closed by the retest after it merges.
