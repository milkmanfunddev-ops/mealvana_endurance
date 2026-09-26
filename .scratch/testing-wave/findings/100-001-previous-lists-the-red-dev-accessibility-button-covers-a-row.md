# 100-001 · Previous lists: the red dev accessibility button covers a row's options button, so that list's menu cannot be opened

- kind: bug
- status: open
- ticket: 100
- run: w39-20260926T1013Z
- screen: Food > Shopping > Previous lists (sheet)
- decision: 

**Steps.**
1. test@test.com, build 72d3723e, simulator 402x874 (iPhone 17 Pro size).
2. Food > Shopping > List options > Previous lists (7 rows).
3. Tap the ⋮ (List options) of the fifth row, "List 2026-09-19" (element at 358,683).

**Expected.**
The row's menu opens (Rename / Delete).

**Actual.**
The red dev "Show accessibility issues" button (368,696) sits on top of that ⋮. The first tap turned the accessibility overlay on (yellow markers on every row), the second turned it off; the row menu never opened. The sheet has no scroll room, so the row cannot be moved out from under it. Worked around by opening the list and using the header's List options. Ticket 68 moved the blue "Open testing tools" button off controls, but the red accessibility button above it still covers row trailing controls at y≈680-710.

**Evidence.**
- runs/100/44-previous-lists.png: the overlay markers after the first tap.
- runs/100/45-handmade-options.png: the sheet after the second tap, no menu.

**Decision quote.**
> 

**Triage.**

