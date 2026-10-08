# 01-002 · A wrong signup code is reported as "That code has expired"

- kind: bug
- status: closed
- ticket: 01
- run: w1-20261007T1103Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up with email (pass A, 11:09:45Z). The code email arrives a second later (code 720817, valid for 1 hour).
2. On "Verify your email", type 720818 (one digit off) and tap Verify at 11:10:30Z, 44 s after the code was sent.

**Expected.**
The code is refused (it was) with a message that says the code is wrong, e.g. "That code is not right. Check the email and try again."

**Actual.**
The code is refused (good: a wrong code is not accepted), but the message is "That code has expired. Tap resend for a new one." The code was never valid and the real one was 44 s old, so the message sends the athlete to Resend, which in this run did not send a new email (01-003). The real code typed next was accepted.
The console shows the same text as `InvalidVerificationCodeException`, and it was reported to Sentry (`error_reported ... InvalidVerificationCodeException`, see 01-005).

**Evidence.**
- runs/01/21-wrong-code-result.png
- runs/01/gmail-codes.txt
- runs/01/console-redacted.log (06:10:30 local, InvalidVerificationCodeException)

**Decision quote.**
> 

**Triage.**
fix ticket: a wrong code gets its own message; expired stays for expired

**Closed (wave 3, 2026-10-08).** the wrong-code reason is right (ticket 21); the raw key it shows is 30-001 (content keys), which supersedes it
