# 86-008 · Log In: wrong password, and a second tap on Log In while it is busy

- kind: followup-test
- status: triaged
- ticket: 86
- run: w25-20260925T1324Z
- screen: Log In
- decision: 

**Steps.**
1. Log In with a wrong password: read the message and check the form re-enables.
2. Log In with the right password and tap Log In a second time while "Logging in…" shows.

**Expected.**
1: a clear wrong-password message, form usable. 2: one sign-in (one `email_sign_in_success`), no second
navigation.

**Actual.**
Not run. The busy state now holds until the tabs shell (12-003 passes), which should make step 2 impossible.

**Evidence.**
- runs/86/02-login-sequence-sheet.png

**Decision quote.**
> 

**Triage.**
Picked for retest ticket 107 (Lee, 2026-09-25).
