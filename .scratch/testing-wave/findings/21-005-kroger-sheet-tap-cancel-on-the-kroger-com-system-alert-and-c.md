# 21-005 · Kroger sheet: tap Cancel on the kroger.com system alert and close the sign-in sheet with X
- kind: followup-test
- status: triaged
- ticket: 21
- run: w17-20260924T2233Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Disconnected, tap Connect Kroger; on the "…Wants to Use “kroger.com” to Sign In" alert tap Cancel.
2. Tap Connect Kroger again, Continue, then close the Kroger sheet with its X before signing in.

**Expected.**
Each time the screen stays disconnected with the Connect button back and a plain message (`authorization_cancelled`), no error in the console, no `kroger_connections` row and no leftover `kroger_oauth_sessions` row.

**Actual.**
Not run (ticket 21 only connects).

**Evidence.**
- runs/21/16-sheet-01-after-connect-tap.png (the alert)

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 90 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 111 when 90 was split (Lee, 2026-09-25).
