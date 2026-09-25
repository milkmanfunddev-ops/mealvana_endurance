# 121-011 · After a correct signup code, Create Your Account shows for about a second before the paywall

- kind: bug
- status: open
- ticket: 121
- run: w34-20260925T2320Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up by email, enter the correct code (23:25:13Z).

**Expected.**
Verify your email goes straight to the onboarding paywall.

**Actual.**
An element read 1 s after the code shows the Create Your Account screen (Apple / Google / Sign up with Email) under an "Account created successfully!" snackbar; the paywall followed ~3 s later (`popping /welcome` at 18:25:13.28, `going to /paywall?onboarding=1` at 18:25:16.20 local). For those seconds the new athlete sees sign-up buttons again. App build e3367d2c.

**Evidence.**
- runs/121/notes.md (23:25:13Z)
- runs/121/12-onboarding-paywall.png
- runs/121/console-redacted.log (18:25:13-18:25:16 local)

**Decision quote.**
> 

**Triage.**

