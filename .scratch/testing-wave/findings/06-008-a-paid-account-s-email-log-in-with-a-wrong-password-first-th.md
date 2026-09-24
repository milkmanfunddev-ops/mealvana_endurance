# 06-008 · A paid account's email Log In with a wrong password first, then the right one

- kind: followup-test
- status: open
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
