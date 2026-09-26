# 118-013 · Events: New Event at the list end with one event, with ten events, and after the tab bar re-expands on scroll-up

- kind: followup-test
- status: open
- ticket: 118
- run: w36-20260926T0031Z
- screen: My Events
- decision: 

**Steps.**
1. Scroll My Events to the end with 1, 5 and 10+ events.
2. Scroll back up so the tab bar expands again, then down to the end.
3. Tap New Event each time.

**Expected.**
New Event rests above the tab bar in the collapsed and expanded states and takes the tap.

**Actual.**
Not run (look-around, ticket 118).

**Evidence.**
- runs/118/43-events-end.png

**Decision quote.**
> 

**Triage.**
