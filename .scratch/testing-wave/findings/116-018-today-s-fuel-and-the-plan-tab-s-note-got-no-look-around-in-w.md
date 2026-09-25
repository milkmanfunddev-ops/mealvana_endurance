# 116-018 · Today's Fuel and the Plan tab's note got no look-around in wave 32

- kind: followup-test
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: Today's Fuel
- decision: 

**Steps.**
Filed by the wave lead: ticket 116 visited these screens but listed no other paths through them.
1. Today's Fuel → "Where it came from" on a day with no meals logged, and right after a logged meal is removed (does the row go, does the count drop).
2. "Where it came from" with two meals of the same meal type and one with no meal type.
3. Today's Fuel on a past day and a future day (the header wording, like 116-009's "INTAKE TODAY").
4. Plan tab Vana card: pull to refresh while the note is loading; the card offline; the card for a day the plan has no meals on.

**Expected.**
Each row names its meal and moves with the logs; empty days say so; the headers name the day shown; the note card ends in either the note or a clear "not available" line, never a spinner that stays (see 115-005).

**Evidence.**
- runs/116/notes.md (screens visited; no look-around lines for Today's Fuel or the Plan tab)
- runs/116/verdicts.md (27-006, 09-002, 14-010 rows)
