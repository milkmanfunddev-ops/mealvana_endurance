# 30-005 · Pre-workout timing reads NOW for a session three days past and nine hours ahead

- kind: bug
- status: triaged
- ticket: 30
- run: w10-20260924T1615Z
- screen: Activity detail (fuelling plan, BEFORE)
- decision: 

**Steps.**
1. Open "12 mi Run" (Monday 21 September 16:45, three days ago). Read the Pre-Workout Snack timing.
2. Open "Patrol H5 1790210557462" from today's "Pre · During · Recovery fuel ›" link (20:45, header "Planned 9h 20m ahead"). Read the Top-Off timing.

**Expected.**
The stored windows: snack "2H TO 30 MIN OUT", top-off "LAST 30 MIN". A relative "NOW …" label only when the window is open.

**Actual.**
12 mi Run snack reads "NOW UNTIL 30 MIN OUT" for a session that ended three days ago. Patrol H5 top-off reads "NOW UNTIL THE START" nine hours before a last-30-minutes top-off. The 12 mi Run's own Top-Off card reads "LAST 30 MIN", so the label is not uniformly relative.

**Evidence.**
- runs/30/08-12mi-run-tap.png
- runs/30/screen-12mi-run-labels.txt
- runs/30/12-patrol-h5-fuel-link.png
- runs/30/screen-patrol-h5-labels.txt
- runs/30/db-fuel-plans-summary.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 62 (Lee, 2026-09-25). Closed by the retest after it merges.
