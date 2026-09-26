# 120-010 · A screenshot taken within a second or two of CRED type shows the password's last character

- kind: idea
- status: triaged
- ticket: 120
- run: w39-20260926T1013Z
- screen: Log In
- decision: 

**Steps.**
Idea (harness). `CRED type` then a `simctl io` screenshot within about two seconds: iOS still shows the last typed character of the password in clear, so the screenshot carries one password character. It happened once this run (deleted, never kept). `CRED type` could wait two seconds after typing, or the runbook could say to wait before a screenshot of a password field.

**Expected.**
No screenshot in RUNS ever carries a password character.

**Actual.**


**Evidence.**
- runs/120/notes.md (the deleted screenshot)

**Decision quote.**
> 

**Triage.**

Fix ticket 142, Harness (wave lead) (Lee, 2026-09-26). Ruling: `CRED type` waits 2 s before any screenshot of a password field (142). ### Ideas and SSOT clashes Closed by the retest after it merges. Record: `triage-20260926.md`.
