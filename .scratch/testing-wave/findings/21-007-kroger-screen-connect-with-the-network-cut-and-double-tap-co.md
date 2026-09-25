# 21-007 · Kroger screen: connect with the network cut, and double-tap Connect Kroger
- kind: followup-test
- status: triaged
- ticket: 21
- run: w17-20260924T2233Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Disconnected, cut the app's network (`netcut.sh on`), tap Connect Kroger.
2. Restore the network; double-tap Connect Kroger quickly.

**Expected.**
Offline: a plain "can't reach Kroger" message, no sheet, nothing stuck busy. Double tap: one sheet, one `kroger_oauth_sessions` row, one connection.

**Actual.**
Not run.

**Evidence.**
- runs/21/13-disconnected-top.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 90 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
