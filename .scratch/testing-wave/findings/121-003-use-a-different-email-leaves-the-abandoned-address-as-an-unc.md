# 121-003 · Use a different email leaves the abandoned address as an unconfirmed auth user on dev

- kind: bug
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up by email with address A, reach Verify your email.
2. Tap Use a different email, sign up and verify address B.
3. SELECT auth.users and public.users for A.

**Expected.**
86-009 steps 1-2: the abandoned address leaves no half-made account behind (or one that is cleaned up).

**Actual.**
auth.users keeps 22ae6961-ddc0-4fbc-9f72-d5d6a6eea039 (lee+e2e-121-20260925t2321za@rightpathprogramming.com, email_confirmed_at null, created 23:22:57Z); no public.users row. Whether it blocks a later signup with A was not tried (it would send another email and make a real account). Left for the wave lead to clean up. App build e3367d2c.

**Evidence.**
- runs/121/db-A-B-after-signup.txt
- runs/121/05-verify-A.png
- runs/121/06-after-use-different-email.png

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Ruling: "Use a different email" deletes the abandoned unconfirmed login at once (139). Closed by the retest after it merges. Record: `triage-20260926.md`.
