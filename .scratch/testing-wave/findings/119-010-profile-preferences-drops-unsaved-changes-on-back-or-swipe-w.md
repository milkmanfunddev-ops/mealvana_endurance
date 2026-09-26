# 119-010 · Profile & Preferences drops unsaved changes on back or swipe without asking

- kind: idea
- status: open
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
