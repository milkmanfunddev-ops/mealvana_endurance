# 32-008 · No success message seen after Reset Password returns to Log In

- kind: followup-test
- status: closed
- ticket: 32
- run: w9-20260924T1447Z
- screen: Set New Password
- decision: 

**Steps.**
1. Forgot Password, enter the emailed reset code, reach Set New Password.
2. Type the new password twice and tap Reset Password.
3. Screenshot the screen that follows within the first second, then again at 4 s.

**Expected.**
The athlete is told the password changed (a MealvanaSnackbar or a line on Log In) before signing in with it.

**Actual.**
The app went back to Log In. The screenshot taken 4 s after the tap shows no message, so either none is shown or it had already gone. Filed by the wave lead from the run notes; the retest takes the first screenshot sooner.

**Evidence.**
- runs/32/20-after-reset-password.png
- runs/32/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 124 (run w37-20260926T0221Z, build 72d3723e): pass; "Password reset successfully" shows on Log In from about 0.6 s to 4 s after the tap.
