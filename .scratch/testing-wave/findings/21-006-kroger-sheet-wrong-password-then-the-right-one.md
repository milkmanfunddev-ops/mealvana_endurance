# 21-006 · Kroger sheet: wrong password, then the right one
- kind: followup-test
- status: triaged
- ticket: 21
- run: w17-20260924T2233Z
- screen: Kroger sign-in sheet
- decision: 

**Steps.**
1. Disconnected, Connect Kroger, Continue; on login.kroger.com type Lee's address and a wrong password, Sign In.
2. Then type the right password (CRED type) and Sign In.

**Expected.**
Kroger's own error inside the sheet, the app waits; the second try connects and the app shows connected. No second-factor screen (none appeared in this run).

**Actual.**
Not run.

**Evidence.**
- runs/21/20-sheet-05-password-typed-masked.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 90 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
