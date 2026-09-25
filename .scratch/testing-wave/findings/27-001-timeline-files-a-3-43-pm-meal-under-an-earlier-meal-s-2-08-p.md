# 27-001 · Timeline files a 3:43 PM meal under an earlier meal's 2:08 PM time card of the same meal type, and two same-time cards swap order after a delete

- kind: bug
- status: triaged
- ticket: 27
- run: w15-20260924T2039Z
- screen: Timeline (Meals filter, also All)
- decision: 

**Steps.**
1. Signed in as test@test.com on 2026-09-24; Food opened once so the day's server rows are on the phone.
2. Log a Meal → Manual: "W15-27 edit", Lunch, saved at 3:43 PM (eaten_at 20:43Z); "W15-27 delete", Snack, saved at 3:44 PM (eaten_at 20:43Z).
3. Timeline → Meals. Later remove "W15-27 delete" through its ⋯ → Remove.

**Expected.**
Each meal sits under its own eaten time (3:43 PM), in time order, as Today's Fuel → Where it came from lists them.

**Actual.**
"W15-27 delete" (Snack, 3:43 PM) is drawn inside the 2:08 PM card with the two earlier snacks (Rice cake, eaten 19:08Z; Cottage Cheese, eaten 19:09Z), and "W15-27 edit" (Lunch, 3:43 PM) inside the other 2:08 PM card under "W13-23 Lunch" (eaten 19:08Z). No 3:43 PM card appears; the 3:17 PM and 3:19 PM cards come after them, so the list is out of time order. After the Remove, the two 2:08 PM cards swapped places (the Lunch card moved above the Snack card). Today's Fuel shows the same rows at their own times (Lunch 3:43 PM, Cottage Cheese 2:09 PM). This answers 26-010's "two meals of one type an hour apart": the timeline groups by meal type under the first meal's time. Totals are not affected.

**Evidence.**
- runs/27/15-timeline-meals-after-logs.png (both 3:43 PM meals under 2:08 PM cards)
- runs/27/21-after-remove-tap.png (the two 2:08 PM cards in swapped order)
- runs/27/23-where-it-came-from.png (Today's Fuel lists the same rows at their eaten times)
- runs/27/db-totals-after-logs.txt (eaten_at of every row)

**Decision quote.**
> 

**Triage.**

Fix ticket 59 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 116 when 92 was split (Lee, 2026-09-25).
