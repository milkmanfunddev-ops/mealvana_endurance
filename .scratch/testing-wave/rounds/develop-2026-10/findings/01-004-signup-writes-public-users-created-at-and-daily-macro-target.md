# 01-004 · Signup writes public.users.created_at and daily_macro_targets.created_at 5 to 10 hours off

- kind: bug
- status: closed
- ticket: 01
- run: w1-20261007T1103Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up with email and confirm the code (simulator time zone CDT, UTC-5).
2. Right after the code is accepted, read `public.users.created_at`, `public.daily_macro_targets.created_at` and `public.onboarding_surveys.created_at` for the new id (all `timestamp with time zone`, default `now()`).

**Expected.**
All three hold the real UTC instant of the write (about the `email_confirmed_at` time).

**Actual.**
- Pass A (confirmed 11:11:02Z): `public.users.created_at` = 01:11:03+00 (10 h early); `daily_macro_targets` first `created_at` = 06:11:07+00 (5 h early); `onboarding_surveys.created_at` = 11:11:04+00 (correct). `updated_at` on the same users row is right (11:11:05Z), and the db `now()` was 11:11:36Z.
- Pass B (confirmed 11:17:30Z): `public.users.created_at` = 06:17:30+00 (5 h early).
- Pass C (confirmed 11:33:26Z): `public.users.created_at` = 06:33:27+00 (5 h early).
The client appears to send local wall-clock time as if it were UTC (5 h = the CDT offset); pass A's 10 h suggests the offset was applied twice on one path. Anything that sorts or ages users by `created_at` (cohorts, "new user" checks, sweeps) reads these wrong.

**Evidence.**
- runs/01/db-A-created-at-check.txt
- runs/01/db-B-after-code.txt
- runs/01/db-C-after-code.txt

**Decision quote.**
> 

**Triage.**
fix ticket: the client writes that send naive local time as created_at send UTC or let the server default

**Closed (wave 3, 2026-10-08).** retest passed in ticket 30 (runs/30/notes.md, PASS 01-004)
