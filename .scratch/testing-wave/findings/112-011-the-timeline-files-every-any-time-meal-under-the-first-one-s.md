# 112-011 · The timeline files every "Any time" meal under the first one's time label (a soup eaten 6:30 PM sits under 6:24 PM)

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Timeline
- decision: 

**Steps.**
1. Log several quick meals with Meal type "Any time" between 6:24 and 6:30 PM, and some with Breakfast/Lunch.
2. Scroll today's timeline (23:38:47Z).

**Expected.**
Each meal sits at its own eaten time, or the label says it is a group.

**Actual.**
Under "6:24 PM": Oatmeal + raisins (6:24), Built bowl (6:24), Banana + peanut butter (6:26), Egg (6:27), Eggs (6:28), Chews (6:29), Red Lentil soup (6:30). Then "6:25 PM" W13-23 Lunch and "6:26 PM" Egg & Veggie Scramble, which were eaten before most of the group above them. The order reads out of time.

**Evidence.**
- runs/112/41-timeline-after-soup.png
- runs/112/52-timeline-today-bottom.png
- runs/112/db-run-rows.txt (eaten_at of each row)

**Decision quote.**
> 

**Triage.**

Fix ticket 137, Timeline and activities (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
