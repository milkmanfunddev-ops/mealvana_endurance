# 69-007 · Scrubbing a lesson to the end without playing it sends education_video_completed with watched_sec equal to the full duration

- kind: bug
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: Lesson player (Mealvana 101 - 1.1)
- decision: 

**Steps.**
1. Learn → lesson 1.1 (duration 1:36). Do not press play.
2. Drag the progress bar to the end (the drag went to 01:36; a nudge back to ~95 % did not stick), then Back.

**Expected.**
`education_video_completed` means the athlete watched the lesson. A scrub with no playback should not count as watched:
no completed event, and `watched_sec` near 0 on `education_video_closed`.

**Actual.**
On Back: `education_video_closed {percent_watched: 100, watched_sec: 96, duration_sec: 96}` and
`education_video_completed {percent_watched: 100, watched_sec: 96, duration_sec: 96}`, with nothing played (the player
showed 00:00 and the play icon until the drag). `watched_sec` reports the furthest position, not time watched (code map
for 50-012 predicted this: `_maxPosition` is the furthest position the listener saw).

**Evidence.**
- runs/69/j04-scrubbed.png player at 01:36 after the drag, never played
- runs/69/console-redacted.log education_video_closed / education_video_completed lines after the scrub (~23:36Z)

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 82 (small UI batch: login hint key, singular Credit, empty-search feedback, write-back toggle re-reads its pref, watched_sec counts played time), fix wave 8 · Lee, 2026-10-09
