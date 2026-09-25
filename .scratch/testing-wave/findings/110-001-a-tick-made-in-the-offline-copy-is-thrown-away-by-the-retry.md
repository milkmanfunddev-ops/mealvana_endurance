# 110-001 · A tick made in the offline copy is thrown away by the retry timer and never reaches the server

- kind: bug
- status: open
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab), offline copy
- decision: 

**Steps.**
Retest of 20-001 (fix ticket 36), case B/C. test@test.com, confirmed plan 666be167, list c667902d.
1. Relaunch the app with the network cut (netcut.sh launch, then on), 21:14:46Z. Food > Shopping shows the offline copy ("Shopping list", offline notice).
2. Tick Avocado (21:15:11Z). The tick store holds `{name: Avocado, checked: true, planId: 666be167}` with no listId and no rowId.
3. Bring the network back 5 s later (21:15:16Z) without a restart; wait 30 s.
Same result in case B (21:11:14Z tick on Mixed vegetables in the offline copy, left offline): the tick is gone 20 s later and after the next offline restart.

**Expected.**
Ticket 36: "A box ticked with no network is written locally first ... and sent when the network returns; it survives a restart." Avocado reaches `shopping_items.checked = true` once online, and stays ticked across an offline restart.

**Actual.**
The retry timer's replay runs against the offline copy, whose rows have no ids, finds "no row" for the tick and deletes it from the store: console `shopping tick dropped: no row for "Avocado"` at 21:15:16Z (and `... "Mixed vegetables"` at 21:11:34Z, 20 s after the case-B tick). Nothing is sent: the DB keeps Avocado unchecked, and the live list that loads once online shows it unticked. No message tells the athlete. Code: `ShoppingListController._replay` drops a tick when `tick.rowId ?? _rowNamed(current, name)` is null, and on the offline copy `_rowNamed` is always null because its items are not `ShoppingListItem`s. So a tick made in the in-store offline case lives at most 20 s. 20-001 fails for ticks made in the offline copy; ticks made on the live list while offline do reach the server (see 110-002).

**Evidence.**
- runs/110/33-clean-C2-offline-before.png — the offline copy before the tick.
- runs/110/34-clean-C2-avocado-tapped.png — Avocado ticked offline.
- runs/110/35-clean-C2-30s.png — online 30 s later: Avocado unticked.
- runs/110/db-04-clean-C2.txt — Avocado checked = false after reconnect.
- runs/110/24-offline-copy-mixed-ticked.png — case B tick on Mixed vegetables.
- runs/110/29-offline-second-restart.png — after the next offline restart Mixed vegetables is unticked.
- runs/110/pending-ticks-after-second-offline-restart.json — the offline-copy tick is gone from the store.
- runs/110/console-redacted.log — 'shopping tick dropped: no row for' at 16:11:34 and 16:15:16 local (21:11:34Z, 21:15:16Z).
- runs/110/notes.md — timeline.

**Decision quote.**
> 

**Triage.**

