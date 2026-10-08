# 69-009 · After Turn Off Sharing the TrainingPeaks card's Write fuel plan toggle still shows on until Connected Apps is reopened

- kind: bug
- status: open
- ticket: 69
- run: w7-20261008T2311Z
- screen: Connected Apps
- decision: 

**Steps.**
1. Settings → Connected Apps, TrainingPeaks connected with sharing on (`flutter.tp_writeback_enabled` 1).
2. Disconnect TrainingPeaks, Connect again (lee.tri) → Allow → the "Your fuel plan goes to your coach" sheet →
   Turn Off Sharing.

**Expected.**
The card's "Write fuel plan to TrainingPeaks" toggle reads off at once, matching the preference.

**Actual.**
23:41:01Z: `flutter.tp_writeback_enabled` read 0 (via `simctl spawn defaults read` on the container plist), but the
card's toggle stayed on (AX value 1, green switch in the screenshot). Back to Settings and into Connected Apps again:
the toggle then read off (0). An athlete who turns sharing off sees it still on and may tap it back on.
Turning the toggle on later (23:42:40Z) updated card and preference together (both 1).

**Evidence.**
- runs/69/k15-after-turn-off.png toggle on right after Turn Off Sharing
- runs/69/k16-reopened.png toggle off after reopening the screen
- runs/69/k19-toggle-on.png toggle on again, preference 1

**Decision quote.**
> 

**Triage.**

