# 50-010 · TrainingPeaks Sync Now tracks integration_connect_started before integration_sync_success

- kind: bug
- status: triaged
- ticket: 50
- run: w5-20261008T1720Z
- screen: Connected Apps (TrainingPeaks card)
- decision: 

**Steps.**
1. TrainingPeaks connected. Tap its Sync Now (17:45:16Z).

**Expected.**
A sync tracks sync events only; `integration_connect_started` belongs to the Connect flow.

**Actual.**
Console at 12:45:16 local: `integration_connect_started {provider: training_peaks, …}` on the Sync Now tap, then
`integration_sync_success {workouts_synced: 0, …}` at 12:45:25. No connect sheet opened. Mixpanel's connect funnel
counts every manual sync as a started connect that never completes. (Same event payloads carry `device_id: <user
id>`, as 32-005 already noted.)

**Evidence.**
- runs/50/console-redacted.log 12:45:16 connect_started, 12:45:25 sync_success
- runs/50/n13-tp-syncing.png the tap

**Decision quote.**
> 

**Triage.**

