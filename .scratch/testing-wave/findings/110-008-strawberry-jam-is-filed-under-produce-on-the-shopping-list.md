# 110-008 · Strawberry jam is filed under Produce on the shopping list

- kind: bug
- status: triaged
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
18-002/18-006 retest: Browse + on Sweet rice cake with jam for conversation 7cc15497 (21:24:12Z) built list 8719653f.

**Expected.**
Jam lands in Pantry (as Pesto and Tahini sauce do).

**Actual.**
Strawberry jam 8 tbsp sits under PRODUCE, presumably matched on "strawberry".

**Evidence.**
- runs/110/db-12-draft-list-items.txt — aisle Produce.
- runs/110/74-draft-list-opened.png — on screen.

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
