# 02-008 · TrainingPeaks sharing sheet on relaunch while the TrainingPeaks token is dead; what Keep and Turn Off write

- kind: followup-test
- status: triaged
- ticket: 02
- run: w1-20261007T1103Z
- screen: Timeline (TrainingPeaks sharing sheet)
- decision: 

**Steps.**
1. On test@test.com (TrainingPeaks connected, refresh token dead: `invalid_grant` in the console), terminate and relaunch the app.
2. After the notification prompt and the launch-trail dialog, the sheet "Your fuel plan goes to your coach" appears with Keep Sharing / Turn Off Sharing.
3. Try each of Keep Sharing, Turn Off Sharing and closing by the scrim, each on a fresh relaunch; read what each writes (integration/sharing flag) and whether the sheet comes back.

**Expected.**
The sheet appears once, at a sensible moment, and does not promise sharing while the TrainingPeaks connection needs a reconnect; each choice writes only the sharing setting it names; closing leaves sharing on as the sheet says.

**Actual.**


**Evidence.**
- runs/02/21-tp-sharing-sheet.png — the sheet on relaunch
- runs/02/notes.md — order of prompts on relaunch; TrainingPeaks invalid_grant in console (known noise)

**Decision quote.**
> 

**Triage.**
retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets)
