# 32-003 · Password reset leaves the recovery session and other sessions signed in

- kind: followup-test
- status: open
- ticket: 32
- run: w9-20260924T1447Z
- screen: Set New Password
- decision: 

**Steps.**
1. Sign an account in on two devices (or one device plus a direct GoTrue password grant).
2. On one, Forgot password, enter the reset code, set a new password.
3. Check `auth.sessions` for the account and try an authenticated call from the other device.

**Expected.**
Decide what a reset should do: most apps sign every other session out when the password changes,
since a reset is often done because someone else has the password. At least the recovery
session the reset screen opened should end once the app returns to Log In.

**Actual.**
Not run as a test. Seen in passing: after the reset and a fresh sign-in, `auth.sessions` still held
the recovery session opened at 14:54:43Z and this run's own GoTrue session from 14:55:29Z, next to
the new 14:56:06Z sign-in. The app's sign-out also uses `SignOutScope.local`.

**Evidence.**
- runs/32/db-auth-user-after-reset.txt
- runs/32/notes.md, line for 14:56:33Z

**Decision quote.**
> 

**Triage.**
