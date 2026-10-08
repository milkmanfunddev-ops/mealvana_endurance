# 50-012 · Follow-up: Learn untried paths (Notify Me twice, Back mid-load, scrub to the end, lessons 1.2 and 1.3)

- kind: followup-test
- status: triaged
- ticket: 50
- run: w5-20261008T1720Z
- screen: Learn, Video player
- decision: 

**Steps.**
1. Notify Me (Pro Videos, Courses) twice: does the button stay "noted", and what row does it write?
2. Leave a lesson mid-load (Back before the video starts) online and offline: events sent?
3. Scrub forward to 95 % without watching, then Back: does `education_video_completed` fire on a skip (furthest point
   reached counts scrubbing)?
4. Lessons 1.2 and 1.3 (only 1.1 was opened).

**Expected.**
No crash; completed only for watched lessons, or a written rule that scrubbing counts.

**Actual.**
Not run.

**Evidence.**
- runs/50/b06-learn.png Learn with Notify Me buttons
- runs/50/i05-at-15pct.png the player controls (15 s skip buttons, scrub bar)

**Decision quote.**
> 

**Triage.**

