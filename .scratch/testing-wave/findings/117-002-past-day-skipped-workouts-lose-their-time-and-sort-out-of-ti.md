# 117-002 · Past-day skipped workouts lose their time and sort out of time order, after the day's evening meals

- kind: bug
- status: open
- ticket: 117
- run: w40-20260926T1052Z
- screen: Timeline
- decision: 

**Steps.**
1. test@test.com, Timeline, Previous day back to Thu 24 Sep, Wed 23 and Fri 25 (days before today that have both meals and skipped workouts).
2. Read the order of cards.

**Expected.**
Every card sits in time order with its time, as today's cards do (30-006: "Each day equals the SQL rows for that day, in time order, in every path").

**Actual.**
Skipped workouts on a past day show no time and are placed after the meals: Thu 24 lists the meals from 2:09 PM to 8:30 PM, then Easy (05:32), Foam Rolling (07:00), Rad Device Test Swim (07:00), Run (07:28) and the two 20:45 Patrol H5 at the bottom with hollow dots. Fri 25 puts R-CORE Routine (07:00) after the 7:25 PM completed Swim. Wed 23 puts its four 07:00 sessions between the 7:42 PM meals and the 9:00 PM brick. Days with only workouts (Sun 20 to Tue 22) look right only because there is nothing else to sort against. The completed Swim and the brick keep their times. The order is at least stable: identical across three visits, a cold start and offline. Whether a skipped session should show its planned time is a product question (30-006 step 1 asked it).

**Evidence.**
- runs/117/11-day-24-top.png
- runs/117/11-day-24-scrolled.png
- runs/117/12-day-25-bottom.png
- runs/117/16-day-23-top-revisit.png
- runs/117/db-week-activities.txt

**Decision quote.**
> 

**Triage.**

