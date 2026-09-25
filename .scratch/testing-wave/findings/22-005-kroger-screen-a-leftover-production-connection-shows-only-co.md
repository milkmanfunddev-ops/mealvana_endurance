# 22-005 · Kroger screen: a leftover production connection shows only Connect Kroger, with no way to see or remove it
- kind: bug
- status: triaged
- ticket: 22
- run: w18-20260925T0127Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. With a `kroger_connections` row for another environment than the function's (test@test.com has a production row while dev runs certification), open Shop with Kroger.
2. Look for Disconnect Kroger; tap Connect Kroger and finish the sign-in (once 22-001 is fixed); read the row after.
3. Check that no send, draft or status call uses the leftover production token.

**Expected.**
The screen treats the account as not connected (`service.ts` status: connected only when the row's environment equals the function's), a finished connect replaces the production row with a certification one, and no call ever reaches Kroger production with the old token.

**Actual.**
Seen in this run: the screen shows Connect Kroger and no Disconnect while the production row (updated 2026-09-24 22:39:27 UTC) stays in the table (09-, db-kroger-after-refused-signin.txt). The replace-on-connect and the no-production-call checks were not reached (22-001).

**Evidence.**
- runs/22/09-kroger-screen.png
- runs/22/db-kroger-after-refused-signin.txt

**Decision quote.**
> 

**Triage.**

Bug, fix ticket 108 (Lee, 2026-09-25, follow-up sort): a connection from the other Kroger environment is shown and can be removed. Retest ticket 109.
Moved to retest ticket 111 when 109 was split (Lee, 2026-09-25).
