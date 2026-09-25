# 88-009 · The chat's swap picker offers the meal being swapped and the draft's other meals as swaps

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Vana chat meal sheet > Swap
- decision: 

**Steps.**
1. New-plan conversation `449da56d`, draft 8ebeb6da with Egg & Veggie Scramble, Wholewheat pasta and Quinoa, mixed veg & walnuts.
2. Tap the swap icon on the Quinoa card; in its sheet tap Swap (20:11:50Z).

**Expected.**
Candidates are other meals: not the meal being swapped out, and not meals already in the draft (or they are marked as such).

**Actual.**
The list's first three are Egg & Veggie Scramble, Wholewheat pasta and Quinoa, mixed veg & walnuts itself, then new meals. Every candidate did carry kcal (61-001 holds). The Plan tab's Swap screen (swap_meal_screen, for the same meal in be6abf2f) did not list the meal itself, so only the chat's picker has this.

**Evidence.**
- runs/88/70-61-001-swap-list.png
- runs/88/72-61-001-swap-meal-screen.png: the Plan tab's Swap screen, for comparison.

**Decision quote.**
> 

**Triage.**

Fix ticket 128 (Lee, 2026-09-25): leave out the meal and every meal already in the plan. Closed by the retest after it merges.
