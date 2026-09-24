# 30-006 · Timeline week walk: past-day cards, filters, hide times, brick card title, pull to refresh, offline

- kind: followup-test
- status: open
- ticket: 30
- run: w10-20260924T1615Z
- screen: Timeline
- decision: 

**Steps.**
1. Past days (Sun 20 to Wed 23) show cards with no time and no "Pre · During · Recovery fuel ›" link, only "Skipped"; today and later show times and the link. Check that is intended, and that "Hide times" toggles both.
2. The Wed 23 brick card shows "BRICK | 3 legs · 124 min", not its title "Patrol Brick 1790211454281"; check a brick's title is meant to be hidden.
3. Workout and Meals filters on a day with sessions and meals; swipe left/right between days instead of the arrows.
4. Pull to refresh after an upstream change (a FinalSurge workout moved or removed) and see the day update.
5. Airplane mode: walk the week from the local database only.
6. Two sessions at the same minute (today's two Patrol H5 at 20:45; Wed's four at 07:00): order is stable across visits.

**Expected.**
Each day equals the SQL rows for that day, in time order, in every path.

**Evidence.**
- runs/30/screen-week-sessions.txt
- runs/30/06-timeline-wed-0923-brick.png

**Triage.**
