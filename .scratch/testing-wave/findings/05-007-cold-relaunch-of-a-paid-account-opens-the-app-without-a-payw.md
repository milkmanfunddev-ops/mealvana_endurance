# 05-007 · Cold relaunch of a paid account opens the app without a paywall frame

- kind: followup-test
- status: triaged
- ticket: 05
- run: w5-20260924T0839Z
- screen: Timeline
- decision: 

**Steps.**
1. Buy Pro through the Test Store on a new account (or resubscribe account B) and reach the timeline.
2. Within the paid period (under 25 minutes, see 05-003), kill the app (`simctl terminate`) and launch it again, with a screen recording at 10 fps or more.
3. Repeat with the network off.

**Expected.**
The app opens straight onto the timeline: no frame of the paywall on the way (criterion 3, mp-457), and offline the SDK's saved answer keeps it open.

**Actual.**
Not run: account B had lapsed (05-003) before this run got to the cold relaunch.

**Evidence.**
- runs/05/18-timeline.png (the state to start from)

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
