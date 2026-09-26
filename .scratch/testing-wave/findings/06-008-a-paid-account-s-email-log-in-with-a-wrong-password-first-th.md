# 06-008 · A paid account's email Log In with a wrong password first, then the right one

- kind: followup-test
- status: closed
- ticket: 06
- run: w6-20260924T1117Z
- screen: Log In
- decision: 

**Steps.**
1. Sign out a paid account. Welcome → I already have an account → Log in with email.
2. Enter the right email and a wrong password → Log In.
3. Enter the right password → Log In. Record the screen from step 2 on.

**Expected.**
Step 2: an error under the form, still on Log In, no paywall and no app. Step 3: the app, with no
paywall frame.

**Actual.**
Not run. This run signed in with the right password once.

**Evidence.**
- runs/06/14-login-filled.png, runs/06/20-sign-in-frames-5fps.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 125 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 125 (run w37-20260926T0221Z, build 72d3723e): pass; a wrong password shows the error and stays on Log In, the right one opens the app with no paywall frame.
