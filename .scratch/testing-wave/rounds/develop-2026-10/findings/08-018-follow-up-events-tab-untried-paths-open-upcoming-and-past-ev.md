# 08-018 · Follow-up: Events tab untried paths (open upcoming and past events, pull to refresh, swipe to dismiss)

- kind: followup-test
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: My Events (Events tab)
- decision: 

**Steps.**
1. Open IRONMAN Cozumel (upcoming) and Baton Rouge Half Marathon (past), Back from each; pull to refresh; swipe a card (onDismissed deletes? check before trying). Recurs from 29-006.

**Expected.**
Each opens its event detail and Back returns to the list; nothing changes unless the user confirms.

**Actual.**


**Evidence.**
- runs/08/b06-events-scrolled.png

**Decision quote.**
> 

**Triage.**
retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets)

**Closed (wave 3, 2026-10-08).** retest passed in ticket 32 (runs/32/notes.md)
