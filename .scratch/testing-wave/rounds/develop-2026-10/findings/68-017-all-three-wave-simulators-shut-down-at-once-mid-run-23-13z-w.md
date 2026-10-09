# 68-017 · All three wave simulators shut down at once mid-run (23:13Z) while host memory was low; the run rebooted its own

- kind: idea
- status: closed
- ticket: 68
- run: w7-20261008T2309Z
- screen: none (wave infrastructure)
- decision: 

**Steps.**
1. 23:13:03Z drag on Food Preferences; ~23:13:05Z wave-pool-1, -2 and -3 all went to Shutdown and this run's log stream was killed (signal 9). vm_stat showed ~5k free pages; a minute later memory_pressure said 28% free.

**Expected.**
Wave simulators stay up for the run, or the runbook says what an agent does when its simulator dies.


**Actual.**
This run booted wave-pool-2 again itself (23:13:49Z), restarted the log stream into a new console.log (the first part kept as console-part1.log) and relaunched; the app kept its sign-in. Idea: a runbook line for a dead simulator (boot your own, new log stream, note the gap), and a check of what else was building or running at 23:13Z.


**Evidence.**
- runs/68/notes.md: the 23:13 entries.

**Decision quote.**
> 

**Triage.**
- closed · IMPROVEMENTS #129: the runbook gets the dead-simulator recovery line and the lead checks free memory before spawning; the cap stays at three · Lee, 2026-10-09
