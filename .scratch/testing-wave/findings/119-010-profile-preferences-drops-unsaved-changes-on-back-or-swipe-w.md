# 119-010 · Profile & Preferences drops unsaved changes on back or swipe without asking

- kind: idea
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Profile & Preferences
- decision: 

**Steps.**
Idea from the 31-005 retest: Profile & Preferences keeps a `_hasChanges` flag but leaving by the top back arrow, the bottom orange arrow or the iOS swipe-back drops the changes with no prompt (they are dropped cleanly; nothing is written). An athlete who taps a TrainingPeaks chip, changes gender and birthday, then swipes back loses all of it silently. Ask "Discard changes?" when `_hasChanges` is true, as most settings forms do.

**Expected.**
A product call for Lee: prompt, or keep dropping silently.

**Actual.**
Idea only.

**Evidence.**
- runs/119/06-after-orange-back.png: back on Settings with no prompt
- runs/119/07-after-swipe-back.png: same after swipe-back

**Decision quote.**
> 

**Triage.**

Fix ticket 138, Settings, connections, allergies, Garmin (Lee, 2026-09-26). Ruling: Profile & Preferences asks "Discard changes?" on back and on swipe when edits are unsaved (138). Closed by the retest after it merges. Record: `triage-20260926.md`.
