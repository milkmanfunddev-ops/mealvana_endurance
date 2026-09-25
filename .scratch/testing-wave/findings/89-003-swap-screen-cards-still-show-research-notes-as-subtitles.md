# 89-003 · Swap screen cards still show research notes as subtitles

- kind: bug
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Swap (Plan tab > meal ⋮ > Swap)
- decision: 

**Steps.**
1. test@test.com, Food > Plan, a meal's ⋮ > Swap.
2. Read the subtitles under the candidate meals.

**Expected.**
Like Browse since ticket 60 (18-004), a candidate's subtitle is its ingredients or nothing, never the research note.

**Actual.**
Every library card on Swap shows the research note: "his dinner base is \"rice, quinoa or wholewheat pasta\" with vegetables ...", "\"A classic, high-carb, low fibre dinner\" — recommended night-before-race carb-load option", "\"one of my go-to dinners (and lunches)\" -- author's plant-based bowl formula ...". The saved meal shows "one of your saved meals". Browse and the Meals tab now show ingredients, so ticket 60's fix did not reach this screen. Related: in Browse the saved "Egg & Veggie Scramble" (no ingredients) repeats its own name as its subtitle.

**Evidence.**
- runs/89/10-19-009-swap-screen.png: the Swap screen's subtitles.
- runs/89/61-18-004-browse-filter-dinner.png: Browse with ingredient subtitles, and the repeated name on Egg & Veggie Scramble.

**Decision quote.**
> 

**Triage.**

Fix ticket 128 (Lee, 2026-09-25). Closed by the retest after it merges.
