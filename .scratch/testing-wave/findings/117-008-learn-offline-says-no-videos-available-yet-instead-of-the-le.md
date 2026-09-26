# 117-008 · Learn offline says No videos available yet instead of the lessons or an offline message

- kind: bug
- status: triaged
- ticket: 117
- run: w40-20260926T1052Z
- screen: Learn
- decision: 

**Steps.**
1. test@test.com signed in; relaunch offline with `netcut.sh on --relaunch` (after the lessons had loaded online in the same install).
2. Open Learn.

**Expected.**
The Mealvana 101 lessons from the last load, or an offline message; not a claim that there is no content.

**Actual.**
Learn shows "No videos available yet" under Mealvana 101 (the online screen lists lessons 1.1, 1.2, 1.3). Console: "Failed to fetch education content: ClientException with SocketException ... Network is unreachable". The Pro Videos and Courses cards render. Nothing is cached, and the empty state reads as if the app has no lessons.

**Evidence.**
- runs/117/53-offline-learn.png
- runs/117/30-learn.png
- runs/117/console-redacted.log

**Decision quote.**
> 

**Triage.**

Fix ticket 141, Accessibility, dev buttons, small fixes (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
