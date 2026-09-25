# 16-007 · Shopping list puts Farro, Spelt and Mixed vegetables under Other and names the list Week of 2026-09-20

- kind: idea
- status: closed
- ticket: 16
- run: w9-20260924T1446Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
Idea, two small things seen on the list built at confirm:
1. Farro (14 oz), Spelt (7 oz) and Mixed vegetables (7 oz) are grouped under Other. The aisle rules (`grocery.ts` AISLE_RULES) have no farro, spelt, freekeh or "mixed vegetables", so grains and vegetables fall through. Adding them would put these rows under Bakery & Grains and Produce (or Frozen).
2. The list's name is "Week of 2026-09-20", an ISO date, while the Plan tab says "Sep 20 – Sep 26". Same-week lists from other plans carry the same name (9bdc9556, adc5b2de, e4d6e247), so a previous-lists view cannot tell them apart.

**Expected.**


**Actual.**


**Evidence.**
- runs/16/10-shopping-list-scrolled.png — the Other group.
- runs/16/list-vs-plan-be6abf2f.txt — rows and aisles.
- runs/16/db-after.txt — four lists named "Week of 2026-09-20".

**Decision quote.**
> 

**Triage.**
Fix ticket 84 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.
Moved to retest ticket 110 when 90 was split (Lee, 2026-09-25).

Run by retest ticket 110 (run w30-20260925T2103Z, build e3367d2c): pass.
