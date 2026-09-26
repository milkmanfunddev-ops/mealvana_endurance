# 121-009 · Every in-app account delete ends with a 403 from /auth/v1/logout

- kind: bug
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Delete account confirm
- decision: 

**Steps.**
1. Delete an account in the app (paywall ⋯ or Settings), online.
2. Read the auth request log for the minute.

**Expected.**
No failing request: after delete-user the session is already gone, so the local sign-out does not call the server, or its 403 is expected and not logged as a failure.

**Actual.**
`POST /auth/v1/logout?scope=local` 403 right after each successful delete-user (18:33:17 for B, 18:37:01 for C, local). The deletes themselves succeeded (no auth.users, public.users or RevenueCat customer left). Log noise in the auth log on every delete. App build e3367d2c.

**Evidence.**
- runs/121/edge-auth-requests-2320-2338.txt
- runs/121/db-rc-B-after-online-delete.txt
- runs/121/db-rc-C-after-delete.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
