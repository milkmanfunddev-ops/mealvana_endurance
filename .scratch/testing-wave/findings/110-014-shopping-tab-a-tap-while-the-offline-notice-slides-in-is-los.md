# 110-014 · Shopping tab: a tap while the offline notice slides in is lost

- kind: followup-test
- status: open
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. Live list on screen, cut the network, tick a row; the offline notice slides in and pushes the rows down about 12 pt.
2. Within a second, tap another row's box.
3. Check the screen, the tick store and, once online, the DB.

**Expected.**
The second tap ticks the row the athlete aimed at, or nothing, never a neighbour; every tick that shows is queued.

**Actual.**
In 110 the first Avocado untick at 21:09:39Z (tapped as the notice appeared) left no trace on screen, in the console or in the store; a second tap at 21:09:52Z worked. Could be the tap landing between rows during the shift.

**Evidence.**
- runs/110/20-offline-live-ticks-0s.png
- runs/110/notes.md

**Decision quote.**
> 

**Triage.**

