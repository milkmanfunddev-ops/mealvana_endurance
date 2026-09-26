# 121-001 · Resend code fails with 429 when tapped as the 30 s countdown ends: the server allows one email per 60 s

- kind: bug
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up by email (dev) and reach Verify your email; the first code mail goes out (23:23:47Z).
2. Wait for "Resend code in Ns" to reach zero and tap Resend code at once (23:24:24Z, ~37 s after the first mail).

**Expected.**
A new code is sent, or the countdown is at least as long as the server's minimum gap between emails, so an enabled Resend always works.

**Actual.**
"Could not resend the code. Please try again." The request was `POST /auth/v1/resend` 429. Dev auth config reads `smtp_max_frequency: 60` (one email per address per 60 s) while the screen's countdown is 30 s (`_resendIn = 30`, verify_email_screen.dart at e3367d2c). A second tap 61 s after the first mail worked ("New code sent to …"). The failed resend writes nothing to the console. App build e3367d2c.

**Evidence.**
- runs/121/08-after-resend.png
- runs/121/09-resend-second-try.png
- runs/121/edge-auth-requests-2320-2338.txt (`resend` 429 at 18:24:24, 200 at 18:24:47 local)
- runs/121/notes.md

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
