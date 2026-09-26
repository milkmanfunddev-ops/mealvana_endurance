# 120-012 · Unsynced rows of one account survive another account's in-app delete on the same phone?

- kind: followup-test
- status: triaged
- ticket: 120
- run: w39-20260926T1013Z
- screen: Paywall
- decision: 

**Steps.**
1. test@test.com offline: Manual log, sign out offline (its dirty row stays).
2. Online, sign up a new account and delete it from the paywall ⋯ → Delete account.
3. Read the local database, then sign in as test@test.com.

**Expected.**
The delete removes only the deleted account's rows; test@test.com's unsynced log stays and uploads at its next sign-in (ticket 102: another account's dirty rows stay for their own next sign-in).

**Actual.**


**Evidence.**
- runs/120/local-drift-04-after-B-signup.txt (test@test.com's dirty rows kept while another account was signed in)

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
