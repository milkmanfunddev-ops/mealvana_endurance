# 125-006 · TrainingPeaks sharing sheet with an account whose TrainingPeaks connection works, and after a reconnect

- kind: followup-test
- status: triaged
- ticket: 125
- run: w37-20260926T0221Z
- screen: Timeline
- decision: 

**Steps.**
1. An account with a working TrainingPeaks connection (is_active true, not requires_reauth). On a freshly wiped app, sign in: What's New, then after it closes the "Your fuel plan goes to your coach" sharing sheet.
2. Swipe the sharing sheet down; Turn Off Sharing on another run and check Settings and the database; relaunch and check it does not come back.
3. Also: an account whose TrainingPeaks row is requires_reauth at first sign-in, then reconnect TrainingPeaks in Connected Apps and relaunch.

**Expected.**
Each sheet shows once and closes by swipe or its button; "Closing this leaves sharing on" holds. For step 3, the sharing notice shows once after the reconnect. The code only offers it right after What's New, which shows once per device, so it may never come.

**Actual.**


**Evidence.**
- runs/125/03-after-whatsnew-swipe.png
- runs/125/04-after-whatsnew-8s.png
- runs/125/notes.md

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
