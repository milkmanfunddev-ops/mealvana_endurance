# 115-001 · After ticking a row on the current confirmed plan's list the header reads An earlier list while a newer draft's list exists

- kind: bug
- status: open
- ticket: 115
- run: w32-20260925T2219Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. test@test.com, week 2026-09-20: confirmed plan 666be167 with list c667902d (confirmed 20:28:08Z) and a draft 9be88811 whose list 8719653f was created later (21:24:12Z, no confirmed_at).
2. Food > Shopping: the list opens as "Week of Sep 20 · Confirmed Sep 25, 2026" (22:23:05Z).
3. Tick one row (Avocado, 22:23:18Z).

**Expected.**
The header stays "Confirmed Sep 25, 2026": this is the tab's current list, the one it opened on.

**Actual.**
Right after the tick the date line reads "Confirmed Sep 25, 2026 · An earlier list" and stays so for the next two ticks (13-tick-one-b.png, 15-three-ticked-later.png). After a cold restart the same list opens without the label (18-cold-shopping-10s.png). Probable cause, from the code: a tick settles through `_settle` → `_summariesWith`, which re-sorts the lists locally by `sortDate` (`confirmedAt ?? createdAt`); the draft's list (created 21:24Z) then sorts ahead of the confirmed list (20:28Z), so `isCurrent` turns false. The server's order put the confirmed list first. Same family as 110-005 (a just-made list and the default list read An earlier list), found here with a different trigger: a tick.

**Evidence.**
- runs/115/11-shopping-first-5s.png — before the tick, no label.
- runs/115/13-tick-one-b.png — after the first tick, "An earlier list".
- runs/115/15-three-ticked-later.png — still labelled after three ticks.
- runs/115/18-cold-shopping-10s.png — after a cold restart, no label.
- runs/115/db-before.txt — the lists and their dates.

**Decision quote.**
> 

**Triage.**
