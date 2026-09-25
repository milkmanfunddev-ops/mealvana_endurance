# 11-013 · The build-lock wait loop released the lock early on the word error in a Swift Package Manager warning

- kind: bug
- status: wontfix
- ticket: 11
- run: w5-20260924T0840Z
- screen: none
- decision: 

**Steps.**
1. An agent waits for its build to finish with a loop that greps the build output for "error".
2. The iOS build prints a Swift Package Manager warning containing the word "error".

**Expected.**
The build lock is held until the build completes (runbook step 6: one build on the Mac at a time).

**Actual.**
The loop matched the warning and released the build lock about a minute before the Patrol build finished. The agent took it back at once; ticket 05 was not building then, so no two builds overlapped this time. The runbook gives no reliable build-done signal to wait on, so each agent writes its own loop.

**Evidence.**
- runs/11/notes.md lines 13-16

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-25): the build lock was removed on 2026-09-24; the wave lead builds once.
