# 67-007 · Wave simulators wave-pool-1 and wave-pool-3 shut down mid-run at 23:13Z; log stream lost

- kind: idea
- status: open
- ticket: 67
- run: w7-20261008T2308Z
- screen: none
- decision: 

**Steps.**
1. Idea: `simulator.mjs` (or the lead) logs simulator state changes with a time, and the runbook gets a recovery line: "simulator
   Shutdown mid-run: `simctl boot`, restart the log stream appending to console.log, relaunch, note the gap".

**Expected.**
A shutdown nobody asked for is recorded with its cause, and agents recover the same way.

**Actual.**
At ~23:13:04Z the log stream ended ("Child process terminated with signal 9: Killed") and `simctl list` showed wave-pool-1 and
wave-pool-3 Shutdown; wave-pool-2 stayed booted. Run 67 did nothing to cause it (last action: CRED new at 23:13Z). Free memory was
29% at 23:14Z. Recovered with `simctl boot`, a new log stream appending to console.log (console gap 23:13:04Z-23:14:37Z) and a
relaunch; app data survived. Cause unknown.

**Evidence.**
- runs/67/67-19b-after-reboot.png
- runs/67/notes.md

**Decision quote.**
> 

**Triage.**

