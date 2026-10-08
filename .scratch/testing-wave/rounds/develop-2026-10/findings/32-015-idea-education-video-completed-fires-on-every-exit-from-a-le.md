# 32-015 · Idea: education_video_completed fires on every exit from a lesson, even at 15% watched

- kind: idea
- status: closed
- ticket: 32
- run: w3-20261008T1256Z
- screen: Learn, lesson player
- decision: folded into fix ticket 41 (video completed only past a threshold)

**Steps.**
1. Rename or gate the event: `video_player_screen.dart:99` sends `education_video_completed` when the player
   closes, whatever was watched. Lesson 1.3 left after 10 s logged `percent_watched: 15`; lesson 1.2 logged 91.
   Either send it only past a threshold, or call it `education_video_closed` and keep `percent_watched`.

**Expected.**
"Completed" in analytics means the lesson was watched.

**Actual.**
`education_video_completed {title: Mealvana 101 - 1.3, percent_watched: 15, watched_sec: 10, duration_sec: 67}` at 08:16:04 local.

**Evidence.**
- runs/32/console-redacted.log 08:15:40 and 08:16:04 `education_video_completed` lines

**Decision quote.**
> 

**Triage.**
