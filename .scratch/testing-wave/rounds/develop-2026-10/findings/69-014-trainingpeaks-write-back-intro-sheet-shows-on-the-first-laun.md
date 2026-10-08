# 69-014 · TrainingPeaks write-back intro sheet shows on the first launch after an app clear for an already-connected athlete

- kind: followup-test
- status: open
- ticket: 69
- run: w7-lead-20261008T2354Zw7-lead-20261008T2354Z
- screen: Connected Apps (TrainingPeaks write-back sheet)
- decision: 

**Steps.**
1. Clear the app's data on a device whose athlete already has TrainingPeaks connected with sharing on (both runs 68 and 69 saw this after the lead's clear: 68 at 23:14:30Z after a relaunch, 69 at 23:24:58Z on its first signed-in cold start).
2. Sign in, relaunch: the "Your fuel plan goes to your coach" sheet shows.
3. Tap Close; relaunch again; sign out and in on the same device.

**Expected.**
Decide whether the intro is per device (shows once per install, Close leaves sharing on and it never returns) or per athlete (should not show to one who already chose). Write down which, and that Close never changes the server row or the pref.

**Actual.**
Filed by the wave lead from runs/68/notes.md (23:14:30Z) and runs/69/notes.md check 3: both runs noted the sheet as not their area; neither checked a second relaunch.

**Evidence.**
- runs/68/notes.md (23:14:30Z, 00b-tp-sharing-sheet-after-relaunch.png)
- runs/69/notes.md check 3 (e01)

**Decision quote.**
> 

**Triage.**

