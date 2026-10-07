# 02-009 · Timeline: a described meal's menu (edit, change an item, delete, move slot)

- kind: followup-test
- status: open
- ticket: 02
- run: w1-20261007T1103Z
- screen: Timeline
- decision: 

**Steps.**
1. With a described meal on the Timeline (402 px wide sim: scroll the card out of y 650-790 before tapping its ⋯, the dev overlay sits there).
2. Open ⋯: edit the meal, change one item, save; compare card, Net Balance and the row (`updated_at`, items, totals).
3. Move it to another slot; delete it (row `is_deleted` true, card gone, Eaten back down).

**Expected.**
Every change shows identically on the card, the Net Balance "Eaten" and the stored row; delete removes it everywhere and survives a relaunch.

**Actual.**


**Evidence.**
- runs/02/17-timeline-after-log.png — the described meal card with its ⋯
- Old Finding: mealplanning-2026-09 23-006 (a described meal on the Timeline, edit food, change an item)

**Decision quote.**
> 

**Triage.**

