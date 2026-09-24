# 26-010 · Timeline groups two snacks eaten a minute apart under the first one's time, and net balance moved 597 kcal for 672 kcal logged

- kind: followup-test
- status: open
- ticket: 26
- run: w13-20260924T1904Z
- screen: Timeline
- decision: 

**Steps.**
1. After the three logs, look at Timeline (Today, September 24).
2. Compare the NET BALANCE before logging (−1,358 kcal at 19:06Z) and after (−761 kcal at 19:10Z).

**Expected.**
Each meal sits at its own eaten time, or the grouping rule is clear on screen. Net balance moves by the kcal logged (168 + 204 + 300 = 672) unless something else changed in between.

**Actual.**
Seen, not yet explained: the 2:08 PM card holds "Rice cake and Almond butter" (eaten 19:08Z) and "Cottage Cheese & Pineapple Bowl" (eaten 19:09Z, both snack), while "Rolled oats and Raisins" (eaten 19:09Z, no meal type) has its own 2:09 PM card. Net balance changed by 597, not 672; the difference may be the burn estimate moving with the clock. Ticket 23's lunch (404 kcal) was not on this phone's timeline. Try on purpose: two meals of one type an hour apart, and a before/after read of net balance with no time passing.

**Evidence.**
- runs/26/04-home.png
- runs/26/19-timeline-after-logs.png
- runs/26/20-timeline-scrolled.png

**Decision quote.**
> 

**Triage.**
