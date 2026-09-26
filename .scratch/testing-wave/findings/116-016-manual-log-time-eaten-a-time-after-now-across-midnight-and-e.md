# 116-016 · Manual log Time eaten: a time after now, across midnight, and editing a logged meal's time, against the timeline's 30-minute grouping

- kind: followup-test
- status: triaged
- ticket: 116
- run: w32-20260925T2220Z
- screen: Log a Meal (Manual)
- decision: 

**Steps.**
1. Manual log with Time eaten set later than now (the text-input clock allows it), and one set so that the meal falls before midnight while logged after it.
2. Edit a logged meal's time (Edit food) so it moves into, and out of, another meal's 30-minute window of the same type.
3. Two meals of one type exactly 30 and 31 minutes apart.
Look-around from this run: the form's Time eaten picker takes any hour, and ticket 59's rule joins same-type meals within 30 minutes of a card's first meal.

**Expected.**
A future time is refused or clearly flagged; each meal lands on its own day; the cards regroup after a time edit and follow the 30-minute rule at its edge.

**Actual.**


**Evidence.**
- runs/116/32-time-picker.png
- runs/116/39-timeline-all-after-logs.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
