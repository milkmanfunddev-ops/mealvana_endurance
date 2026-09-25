# 121-004 · public.users.created_at is the phone's local wall clock stamped as UTC

- kind: bug
- status: open
- ticket: 121
- run: w34-20260925T2320Z
- screen: Verify your email
- decision: 

**Steps.**
1. On a simulator in US Central time (UTC-5), sign up a new account by email and verify it (23:25:13Z).
2. SELECT created_at from public.users and auth.users for it.

**Expected.**
public.users.created_at is the real instant, about 23:25Z, as auth.users.created_at and updated_at are.

**Actual.**
public.users.created_at = 2026-09-25 18:25:13+00: the local time 18:25:13 written as UTC, five hours early, with whole seconds. auth.users.created_at 23:23:46Z, public.users.updated_at 23:25:17Z. xuan@mealvana.io shows the same shape (public 2026-09-21 21:42:34+00 vs auth 2026-09-22 12:42:33Z); rows made by the server (vana-eval accounts) are right. Anything that sorts or ages accounts by public.users.created_at is off by the athlete's UTC offset. App build e3367d2c.

**Evidence.**
- runs/121/db-A-B-after-signup.txt
- runs/121/notes.md

**Decision quote.**
> 

**Triage.**

