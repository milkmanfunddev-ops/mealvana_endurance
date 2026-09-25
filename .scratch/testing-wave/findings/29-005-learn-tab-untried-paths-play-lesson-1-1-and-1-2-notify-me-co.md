# 29-005 · Learn tab untried paths: play lesson 1.1 and 1.2, Notify Me, Courses; console for video player errors

- kind: followup-test
- status: triaged
- ticket: 29
- run: w16-20260924T2100Z
- screen: Learn
- decision: 

**Steps.**
1. Cold start, sign in, open Learn.
2. Play Mealvana 101 lesson 1.1 (1:37) and 1.2; leave the player mid-play; tap Notify Me under Premium Video Library; scroll to Courses.
3. Read the console.

**Expected.**
Video plays and stops cleanly with no player or network error lines; Notify Me gives feedback and does not write twice on a second tap; Courses renders.

**Actual.**
Not run. The run only looked at Learn's first screen: two lesson cards with plain panels and no thumbnail image, Pro Videos "Coming Soon" with Notify Me, and Courses below the fold. Console clean for that screen.

**Evidence.**
- runs/29/11-learn-tab.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 117 when 92 was split (Lee, 2026-09-25).
