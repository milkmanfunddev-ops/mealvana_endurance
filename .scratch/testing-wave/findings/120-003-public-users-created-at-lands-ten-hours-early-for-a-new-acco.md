# 120-003 · public.users.created_at lands ten hours early for a new account (twice the phone's UTC offset)

- kind: bug
- status: triaged
- ticket: 120
- run: w39-20260926T1013Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up a new account by email on a simulator whose clock zone is UTC-5 (lee+e2e-120-20260926T1024Z, Create Account 10:26:36Z, code entered 10:26:54Z).
2. Read `auth.users.created_at` and `public.users.created_at` on dev, and the local Drift `users.created_at`.

**Expected.**
public.users.created_at is the signup moment, about 10:26Z, like auth.users.created_at.

**Actual.**
auth.users.created_at 10:26:37Z; public.users.created_at 2026-09-26 00:26:53+00, ten hours early. The local Drift row holds 1790400413 = 05:26:53 as a UTC epoch, the phone's local wall-clock time stored as UTC (five hours off), and the upload shifts it five hours again. Anything that sorts or reports by public.users.created_at (sign-up cohorts, analytics) is off by twice the phone's UTC offset.

**Evidence.**
- runs/120/db-05-B-after-signup.txt (public.users.created_at 00:26:53+00)
- runs/120/notes.md (the local epoch and the auth.users comparison)

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
