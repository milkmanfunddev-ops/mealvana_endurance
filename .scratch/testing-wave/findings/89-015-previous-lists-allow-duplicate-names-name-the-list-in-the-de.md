# 89-015 · Previous lists: allow duplicate names, name the list in the delete dialog, say why an empty name does not save

- kind: idea
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Food (Shopping sub-tab) > Previous lists
- decision: 

**Steps.**
- Rename to a name another list has ("List 2026-09-19") is accepted; the sheet then shows two same-named rows told apart only by date. Either refuse it or add a suffix.
- The row menu's Delete asks "Delete this list? Everything on it goes with it." without naming the list; with two same-named lists the athlete cannot be sure which goes. Put the name (and date) in the dialog.
- Save with an empty name does nothing and says nothing; disable Save or say a name is needed.
- A 123-character name is saved whole; lists have no cap while plan names cap at 60 (PLAN_NAME_MAX).

**Expected.**


**Actual.**


**Evidence.**
- runs/89/20-19-007-duplicate-name.png: two "List 2026-09-19" rows.
- runs/89/24-19-007-sheet-row-delete-dialog.png: the delete dialog.
- runs/89/19-19-007-sheet-long-name.png: the long name.

**Decision quote.**
> 

**Triage.**

Fix ticket 130 (Lee, 2026-09-25): all four parts. Closed by the retest after it merges.
