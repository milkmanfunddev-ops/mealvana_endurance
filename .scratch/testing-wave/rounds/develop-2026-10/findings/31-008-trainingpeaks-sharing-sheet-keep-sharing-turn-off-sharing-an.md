# 31-008 · TrainingPeaks sharing sheet: Keep Sharing, Turn Off Sharing and the scrim still untested (sheet stays hidden while TrainingPeaks needs a reconnect)

- kind: followup-test
- status: triaged
- ticket: 31
- run: w3-20261008T1256Z
- screen: Timeline (TrainingPeaks sharing sheet)
- decision: retest ticket 51 (Lee's phone / healthy TrainingPeaks account), wave 5

**Steps.**
1. On an account whose TrainingPeaks connection is active and healthy (not requires_reauth), with `flutter.tp_writeback_notice_shown` absent, launch: the sheet should show once.
2. Close by the scrim; read `flutter.tp_writeback_notice_shown` / `flutter.tp_writeback_enabled`; relaunch.
3. Reset the notice key (simctl defaults delete), relaunch, Turn Off Sharing; read the keys. Reset, relaunch, Keep Sharing; read the keys.

**Expected.**
Scrim: shown=true, enabled=true; Turn Off: enabled=false; Keep: enabled=true; the sheet does not come back after any of them.

**Actual.**


**Evidence.**
- runs/31/04-relaunch-no-tp-sheet.png — no sheet on relaunch with TrainingPeaks requires_reauth
- runs/31/notes.md — 02-008 entry: prefs absent at 12:58:30Z and after the last relaunch

**Decision quote.**
> 

**Triage.**

