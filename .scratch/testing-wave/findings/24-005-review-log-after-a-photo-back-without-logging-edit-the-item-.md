# 24-005 · Review & Log after a photo: Back without logging, edit the item, empty name, and the slot the model picks against the clock

- kind: followup-test
- status: triaged
- ticket: 24
- run: w14-20260924T2015Z
- screen: Review & Log
- decision: 

**Steps.**
1. After a photo analysis, tap Back without logging: is the call still charged, and is the uploaded
   photo left in `meal-photos` with no meal row pointing at it?
2. Edit the item (pencil) and log: totals follow the edit in the row and on the timeline.
3. Clear the meal name and log.
4. Log a photo at breakfast time. This run logged at 3:19 PM local and the model pre-selected Dinner for
   a bowl of spaghetti; check whether the slot follows the dish or the clock, and whether that is wanted.

**Expected.**
1: the charge stands (the call ran), an orphan photo is either cleaned up or accepted. 2: edited numbers
saved. 3: a default name or a message. 4: a slot the athlete would expect for the time.

**Actual.**


**Evidence.**
- runs/24/09-review.png: Review & Log with Dinner pre-selected at 3:18 PM local.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 114 when 91 was split (Lee, 2026-09-25).
