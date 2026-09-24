# 05-011 · The wall clock jumped from 08:52Z to 10:47Z mid-run, hiding the live expiry the ticket watched

- kind: idea
- status: open
- ticket: 05
- run: w5-20260924T0839Z
- screen: none
- decision: 

**Steps.**
Record why an agent's wall clock can jump about two hours between two steps (a long-blocking tool call, a sleeping Mac, a paused session), and have the runbook say that a scenario that must be watched live (an expiry, a renewal) checks the time before and after each wait.

**Expected.**
A run that watches something happen at a set time sees it live, or says it could not.

**Actual.**
Between two steps the clock went from about 08:52Z to 10:47Z, cause unknown, with the app in the foreground. The renewals and the expiry were read afterwards from RevenueCat and the webhook logs instead of seen live. Written by the wave lead from the run's notes.

**Evidence.**
- runs/05/notes.md lines 15-17

**Decision quote.**
> 

**Triage.**

