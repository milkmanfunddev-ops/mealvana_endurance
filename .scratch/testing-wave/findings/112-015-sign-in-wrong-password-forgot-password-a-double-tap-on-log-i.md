# 112-015 · Sign-in: wrong password, Forgot Password, a double tap on Log In, and sign-in offline

- kind: followup-test
- status: open
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log In
- decision: 

**Steps.**
1. Log in with a wrong password; read the message.
2. Double tap Log In with the right password (the button shows "Logging in..." for ~10 s here).
3. Sign in with the app offline (`netcut.sh on --relaunch`).
4. After sign-in the What's New sheet showed; on the next relaunch a notification permission prompt covered the timeline. Check both appear once, not on every launch.

**Expected.**
Clear error, one sign-in, a clear offline message; each first-run prompt once.

**Actual.**


**Evidence.**
- runs/112/02-login-filled.png
- runs/112/04-whats-new.png
- runs/112/51-relaunch-netcut.png

**Decision quote.**
> 

**Triage.**
