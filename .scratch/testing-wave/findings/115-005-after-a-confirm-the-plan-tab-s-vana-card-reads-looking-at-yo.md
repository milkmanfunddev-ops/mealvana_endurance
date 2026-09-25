# 115-005 · After a confirm the Plan tab's Vana card reads Looking at your day for 20 s or more while the day note is rebuilt

- kind: followup-test
- status: open
- ticket: 115
- run: w32-20260925T2219Z
- screen: Food (Plan sub-tab)
- decision: 

**Steps.**
1. Confirm a draft from the Review sheet (this run: 22:33:48Z, test@test.com).
2. Open Plan and time how long the Vana card reads "Looking at your day...".

**Expected.**
The new note within a few seconds, or the old note until the new one is ready.


**Actual.**
Seen once, not timed: the `vana.daynotes` call finished at 22:33:58.75Z (vana_calls), yet at 22:34:20Z the card still read "Looking at your day..." (33-plan-after-confirm.png). It may have been filled a moment later; ticket 116 reads this note on the same account. Time it from confirm to the note.


**Evidence.**
- runs/115/33-plan-after-confirm.png — "Looking at your day..." 30 s after confirm.
- runs/115/db-after-confirm.txt — the vana_calls row at 22:33:58Z.

**Decision quote.**
> 

**Triage.**

