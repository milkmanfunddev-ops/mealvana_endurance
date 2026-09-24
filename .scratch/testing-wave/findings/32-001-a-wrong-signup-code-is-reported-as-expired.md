# 32-001 · A wrong signup code is reported as expired

- kind: bug
- status: open
- ticket: 32
- run: w9-20260924T1447Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up with email on dev (confirm-by-email on). The Verify your email screen opens and the code email arrives.
2. Type a code that was never sent (123456) and tap Verify.
3. Tap Resend code, wait for the second email, then type the first code (now superseded) and tap Verify.

**Expected.**
Step 2 says the code is wrong ("That code is not right. Check it and try again.", the string the
service already has for this case). Step 3 may say expired or no longer valid.

**Actual.**
Both say "That code has expired. Tap resend for a new one." A code that was mistyped reads as
expired, which sends the athlete to Resend instead of rechecking the digits. Cause, from the code:
`EmailAuthService.verifyEmailOtp` picks the expired text whenever the GoTrue message contains
"expired", and GoTrue answers every bad code with "Token has expired or is invalid", so the
"not right" branch never runs. The Forgot password code screen was not tried with a wrong code
(Finding 02-012 covers that screen).

**Evidence.**
- runs/32/07-wrong-code.png
- runs/32/09-superseded-code.png
- runs/32/console-excerpts.log, section A (09:51:32 and 09:52:25 local, `InvalidVerificationCodeException: That code has expired`)
- runs/32/notes.md, lines for 14:51:32Z and 14:52:25Z

**Decision quote.**
> 

**Triage.**
