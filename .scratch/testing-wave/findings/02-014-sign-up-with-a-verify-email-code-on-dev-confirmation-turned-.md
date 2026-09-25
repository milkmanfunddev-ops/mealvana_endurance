# 02-014 · Sign up with a verify-email code on dev (confirmation turned on)

- kind: followup-test
- status: triaged
- ticket: 02
- run: w2-20260923T1442Z
- screen: Verify Email
- decision: 

**Steps.**
Dev has mailer_autoconfirm on, so signup never shows the verify screen and ticket 02 could not test it. With confirmation on (a branch project, or dev briefly, at Lee's say), sign up at a lee+e2e address, read the code with the Gmail tool, and run integration_test/flows/account_delete_flow_test.dart with scripts/testing-wave/code-probe.mjs serving.

**Expected.**
The code arrives at the plus address, the verify screen accepts it, and the Patrol flow's probe path gets past the verify screen.

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).
