# 02-006 · Review: back without logging, rename, Any time slot, remove and swap an item

- kind: followup-test
- status: triaged
- ticket: 02
- run: w1-20261007T1103Z
- screen: Review & Log
- decision: 

**Steps.**
On Review & Log after a describe call (one AI logging spend):
1. Back (top-left) without logging: does the sheet come back with the text kept, and is a second Analyze another token?
2. Clear the meal name: is "Log this meal" disabled or does it fail silently (`_logMeal` returns early on an empty name)?
3. Pick "Any time" (deselect the slot) and log: row `slot` null, card placement.
4. Swipe an item to swap it via the food picker; remove an item, if the editor allows; log and compare row items and totals.

**Expected.**
Back loses nothing it should keep and never charges twice for one analysis; an empty name says why it will not log; slot null stores and shows as Any time; a swapped or removed item changes the totals, the row and the card identically.

**Actual.**


**Evidence.**
- runs/02/09-review-top.png — Review & Log controls (slot chips, items, edit buttons)
- Old Finding: mealplanning-2026-09 23-004 (Review back without logging, edit an item, rename, change quantity)

**Decision quote.**
> 

**Triage.**
retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets)
