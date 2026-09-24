# 12-008 · First login stacks the What's New sheet and the TrainingPeaks sharing sheet over the timeline

- kind: followup-test
- status: open
- ticket: 12
- run: w4-20260924T0417Z
- screen: Timeline
- decision: 

**Steps.**
1. First login on a fresh install as an account with a TrainingPeaks connection (the admin has one).
2. The What's New sheet ("Shake to tell us what's wrong") opens; after Got it, the "Your fuel plan goes to your coach" TrainingPeaks sharing sheet opens.
3. Try: swipe each sheet down instead of the buttons; Turn Off Sharing and check the setting in Settings and the database; relaunch and check neither sheet comes back; background the app while a sheet is up.

**Expected.**
Each sheet shows once, closes by swipe or its buttons, and "Closing this leaves sharing on" holds.

**Actual.**

**Evidence.**
- runs/12/04c-timeline-with-whats-new-sheet.png, runs/12/05a-tp-sharing-sheet.png

**Decision quote.**
> 

**Triage.**

