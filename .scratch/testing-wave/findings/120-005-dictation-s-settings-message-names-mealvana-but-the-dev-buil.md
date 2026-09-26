# 120-005 · Dictation's settings message names Mealvana, but the dev build is Endurance Dev in iOS Settings, and the snackbar covers the composer

- kind: idea
- status: triaged
- ticket: 120
- run: w39-20260926T1013Z
- screen: Vana chat
- decision: 

**Steps.**
Idea. After Don't Allow on Speech Recognition, a tap on Dictate shows "Dictation needs Speech Recognition and Microphone access. Turn them on in iOS Settings → Mealvana." On the dev build the app is "Endurance Dev" in iOS Settings, so the path it names does not exist there (prod may be fine). The snackbar also sits over the composer while it shows, so the text field cannot be tapped for about 4 s.

**Expected.**
The message names the app as iOS Settings lists it (from the bundle's display name), and the composer stays usable while it shows.

**Actual.**


**Evidence.**
- runs/120/16-after-dont-allow.png
- runs/120/17-second-dictate-tap.png

**Decision quote.**
> 

**Triage.**

Fix ticket 141, Accessibility, dev buttons, small fixes (Lee, 2026-09-26). Ruling: the dictation message names the app as iOS Settings lists it, and stays clear of the composer (141). Closed by the retest after it merges. Record: `triage-20260926.md`.
