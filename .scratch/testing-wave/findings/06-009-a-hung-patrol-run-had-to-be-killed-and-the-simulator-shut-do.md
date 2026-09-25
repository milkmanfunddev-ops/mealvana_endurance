# 06-009 · A hung Patrol run had to be killed, and the simulator shut down with it

- kind: bug
- status: wontfix
- ticket: 06
- run: w6-20260924T1117Z
- screen: none
- decision: 

**Steps.**
1. Run a Patrol flow on a pool simulator.
2. The flow fails at a `waitUntilVisible` (here: the tab bar under the What's New scrim).

**Expected.**
Patrol reports the failure and exits; the simulator stays up for the next run.

**Actual.**
Patrol hung from the failure until it was killed at 11:55Z, and the simulator shut down with it and had to be booted again. The harness has no timeout on a Patrol run and no note on recovering the device. Written by the wave lead from the run's notes.

**Evidence.**
- runs/06/notes.md, Patrol section (Run 1)
- runs/06/25-patrol-stuck-state.png

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-25): Patrol left the testing waves on 2026-09-24, so no Patrol run hangs a wave simulator any more.
