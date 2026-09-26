# 110-002 · Ticks made offline on the live list vanish from the offline copy after a restart, though they are still queued and later sent

- kind: bug
- status: triaged
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab), offline copy
- decision: 

**Steps.**
Retest of 20-001 (fix ticket 36), case A then B.
1. Live list c667902d on screen (Avocado and Wholewheat pasta ticked, Mixed vegetables not). Cut the network (21:09:33Z).
2. Tick Mixed vegetables (21:09:38Z) and untick Avocado (21:09:52Z). The screen keeps both and shows the offline notice.
3. Cold restart with the network still cut (21:10:21Z), Food > Shopping.

**Expected.**
The offline copy shows the athlete's own ticks: Mixed vegetables ticked, Avocado unticked.

**Actual.**
The offline copy shows the server's old state: Avocado ticked, Mixed vegetables unticked. Both ticks are still in the tick store (pending-ticks-after-offline-restart.json) and were sent when the network came back at 21:12:45Z (DB: Avocado false, Mixed true), so nothing is lost, but for the whole offline stretch the list in the athlete's hand shows the opposite of what they ticked. Cause from reading the code: ticks made on the live list carry `listId`, `PendingShoppingTick.appliesTo` matches on listId first, and the offline copy has `listId == null`, so `_withPending` does not lay them over it.

**Evidence.**
- runs/110/22-offline-live-10s.png — live list offline: Avocado unticked, Mixed ticked.
- runs/110/23-offline-cold-shopping.png — offline copy after the restart: the reverse.
- runs/110/pending-ticks-after-offline-restart.json — both ticks queued with listId c667902d.
- runs/110/db-01-after-reconnect.txt — both reached the DB after reconnect.
- runs/110/notes.md — timeline.

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
