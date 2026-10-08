# 50-015 · Follow-up: AI Credits ('1 Credits' copy, /buy-credits signed out, Restore with nothing to restore)

- kind: followup-test
- status: closed
- ticket: 50
- run: w5-20261008T1720Z
- screen: AI Credits
- decision: 

**Steps.**
1. The tester pack reads "1 Credits / $0.99 one-time purchase" (g01): singular copy.
2. Open `/buy-credits` signed out; open it with AI credits off (Coming Soon body names no Formula Kit, from code).
3. Restore with no purchases (sandbox) — only on an account a ticket names for RevenueCat writes.

**Expected.**
Plural-correct copy; signed out redirects to Welcome; Restore states its result.

**Actual.**
Not run (1 seen only).

**Evidence.**
- runs/50/g01-buy-credits.png "1 Credits"

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 69 check 14 ran it; "1 Credits" is 69-013) · lead, 2026-10-09
