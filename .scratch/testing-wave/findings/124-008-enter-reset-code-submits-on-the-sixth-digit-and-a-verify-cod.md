# 124-008 · Enter Reset Code submits on the sixth digit, and a Verify Code tap right after sends a second verify

- kind: followup-test
- status: open
- ticket: 124
- run: w37-20260926T0221Z
- screen: Enter Reset Code
- decision: 

**Steps.**
1. Enter a six-digit code and tap Verify Code right away.
2. Read the console for the number of verify calls, with a wrong code and with the right one.

**Expected.**
One verify per code; with the right code no second call and no error.

**Actual.**
Not run as a test. Seen in passing: each wrong code logged two "Reset code verification failed" 0.6 s apart (02:36:32.8Z and 02:36:33.4Z; 02:37:58.5Z and 02:37:59.1Z), the first before the Verify Code tap, so the field submits on the sixth digit. With the right code, the tap then landed on Set New Password and hit its Reset Password button with empty fields ("Password is required" showed on arrival). The code map does not mention auto-submit on this screen.

**Evidence.**
- runs/124/32-reset-wrong-code.png
- runs/124/36-set-new-password.png
- runs/124/console-redacted.log

**Decision quote.**
> 

**Triage.**

