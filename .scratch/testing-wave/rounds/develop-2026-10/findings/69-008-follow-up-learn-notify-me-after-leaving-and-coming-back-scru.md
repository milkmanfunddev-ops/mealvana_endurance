# 69-008 · Follow-up: Learn, Notify Me after leaving and coming back, scrub then play, lessons 1.4 and 1.5, a lesson with no video

- kind: followup-test
- status: open
- ticket: 69
- run: w7-20261008T2311Z
- screen: Learn
- decision: 

**Steps.**
1. Notify Me on "Premium Video Library", leave Learn for another tab, come back, tap again: the button is State-local
   ("Noted" may reset), so does a second `education_notify_me_tapped` fire? Same for "Structured Learning Paths".
2. Scrub a lesson to 50 %, then play 10 s, then Back: what percent_watched and watched_sec are sent?
3. Open lessons 1.4 and 1.5 (cards at the far end of the carousel; their cards, like 1.2 and 1.3, show no duration
   while 1.1 shows 1:37, and the server has duration_seconds null for them).
4. A lesson with an empty video_url (none exists on dev today; needs a test row): "Failed to load video", no closed or
   completed event.
5. Rotate to landscape / full-screen button mid-lesson, then Back.

**Expected.**
One notify event per real request; watch metrics reflect time actually played; every lesson card shows its length.

**Actual.**
Not run. Seen this run: Notify Me twice in place → one event, button "Noted" (disabled); Back before load → opened
only; lessons 1.2 and 1.3 load (01:24, 01:07).

**Evidence.**
- runs/69/j01-notify-1.png "Noted" after the first tap
- runs/69/j08-carousel-end.png lessons 1.4 and 1.5 without a duration
- runs/69/db-education-content.txt five published lessons, all with a video

**Decision quote.**
> 

**Triage.**

