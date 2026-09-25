# 30-007 · Month picker: days with only skipped sessions carry no marker; tap a day, month arrows, Today

- kind: followup-test
- status: triaged
- ticket: 30
- run: w10-20260924T1615Z
- screen: Month picker (timeline date dropdown)
- decision: 

**Steps.**
1. Open the date dropdown on the timeline. September 2026: 16 has a green dot (completed swim), 24-30 have orange rings, but 17-23 carry no marker though each has 2-5 planned (Skipped) sessions. Check whether skipped days should carry a marker.
2. Tap a day (worked for the 21st), use the month arrows, tap "Today", swipe the sheet down.
3. A day with a completed and a skipped session.

**Expected.**
Markers follow what the timeline shows for that day; every path lands on the chosen day.

**Evidence.**
- runs/30/07-month-picker.png

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 117 when 92 was split (Lee, 2026-09-25).
