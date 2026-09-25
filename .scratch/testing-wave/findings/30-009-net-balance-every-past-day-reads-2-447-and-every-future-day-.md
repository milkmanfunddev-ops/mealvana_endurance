# 30-009 · Net balance: every past day reads -2,447 and every future day +0

- kind: followup-test
- status: triaged
- ticket: 30
- run: w10-20260924T1615Z
- screen: Timeline (NET BALANCE)
- decision: 

**Steps.**
1. Sun 20, Mon 21, Tue 22 and Wed 23 all read "-2,447 kcal deficit — time to eat"; Thu 24 (today) reads -1,039; Fri 25 and Sat 26 read "+0 kcal on track".
2. Expand the NET BALANCE card on each and compare its parts with the day's sessions and meal logs.

**Expected.**
A past day's balance depends on that day's sessions and logs; a future day with planned sessions does not read "on track" at +0. Related: 05-009.

**Evidence.**
- runs/30/05-timeline-sun-0920.png
- runs/30/06-timeline-tue-0922.png
- runs/30/06-timeline-fri-0925.png
- runs/30/06-timeline-sat-0926.png
- runs/30/04-timeline-thu-0924-top.png

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
