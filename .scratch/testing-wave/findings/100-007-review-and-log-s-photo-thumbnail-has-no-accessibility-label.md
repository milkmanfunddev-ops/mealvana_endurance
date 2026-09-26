# 100-007 · Review and Log's photo thumbnail has no accessibility label

- kind: bug
- status: open
- ticket: 100
- run: w39-20260926T1013Z
- screen: Review & Log (photo log)
- decision: 

**Steps.**
1. Log a Meal > Describe > Gallery, pick a photo, Analyze.
2. Read the element list on Review & Log.

**Expected.**
The new thumbnail (ticket 97) carries a label, for example "Photo being logged".

**Actual.**
The photo draws at the top of the screen but is absent from the accessibility tree; VoiceOver users do not learn which photo the numbers came from.

**Evidence.**
- runs/100/71-review-and-log.png

**Decision quote.**
> 

**Triage.**

