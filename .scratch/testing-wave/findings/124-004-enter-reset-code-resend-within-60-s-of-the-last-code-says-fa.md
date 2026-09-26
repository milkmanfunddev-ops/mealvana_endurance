# 124-004 · Enter Reset Code: Resend within 60 s of the last code says 'Failed to resend code' with no wait time; the screen has no cooldown

- kind: bug
- status: open
- ticket: 124
- run: w37-20260926T0221Z
- screen: Enter Reset Code
- decision: 

**Steps.**
1. Forgot Password > account A > Send Reset Code (02:36:21Z).
2. About 20 s later tap "Didn't receive a code? Resend" (02:36:43Z).
3. Wait 60 s and tap Resend again (02:37:42Z).

**Expected.**
Resend either works or says how long to wait; the link is disabled until the server allows another email (as the code screen at signup counts down, 121-001).

**Actual.**
Step 2: snackbar "Failed to resend code. Please try again." The server answered 429
`over_email_send_rate_limit` "you can only request this after 37 seconds"; the app drops the wait
time. The link has no cooldown at all. Step 3 worked ("A new code has been sent to your email",
recovery_sent_at 02:37:43Z). Same 60 s server limit as 121-001, on the reset screen.

**Evidence.**
- runs/124/33-reset-resend.png
- runs/124/34-reset-resend-after-wait.png
- runs/124/console-redacted.log (over_email_send_rate_limit)

**Decision quote.**
> 

**Triage.**

