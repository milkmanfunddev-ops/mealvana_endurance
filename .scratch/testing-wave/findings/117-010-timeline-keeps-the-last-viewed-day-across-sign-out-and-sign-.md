# 117-010 · Timeline keeps the last viewed day across sign-out and sign-in, and into a different account

- kind: bug
- status: open
- ticket: 117
- run: w40-20260926T1052Z
- screen: Timeline
- decision: 

**Steps.**
1. test@test.com: walk the Timeline back to Sunday, September 20. Settings, Sign Out, Sign out.
2. Log in again with test@test.com (11:09:19Z).
3. Sign out, sign up a new account and buy Monthly (11:13:45Z).

**Expected.**
A sign-in (and a new account above all) opens the Timeline on today.

**Actual.**
Both land on "Sunday, September 20", the day last viewed before sign-out: test@test.com again (net balance −2,447), and the brand-new account right after its purchase (−2,006 on a day before it existed). A cold relaunch does open on today. The selected day survives sign-out, so it is kept per app, not per account.

**Evidence.**
- runs/117/62-after-second-signin-opens-sep20.png
- runs/117/78-after-purchase.png
- runs/117/notes.md

**Decision quote.**
> 

**Triage.**

