# 67-004 · Log In's password field shows the sign-up hint 'At least 8 characters'

- kind: bug
- status: open
- ticket: 67
- run: w7-20261008T2308Z
- screen: Log In
- decision: 

**Steps.**
1. Welcome → I already have an account → Log in with email (also reached from Verify your email's hint "Log in").
2. Tap the Password field.

**Expected.**
A login hint ("Enter your password", the screen's code default), not the sign-up rule.

**Actual.**
The empty Password field shows "At least 8 characters" (23:24Z and 23:27Z). `email_login_screen.dart:288-291` reads the sign-up
screen's content key `auth.email_signup.password_hint`, whose content default is "At least 8 characters"
(`assets/config/content_defaults.json:281`), so the code default "Enter your password" never shows. Small copy slip; an athlete with an
older short password may read it as a rule.

**Evidence.**
- runs/67/67-36-login-password-focus.png
- runs/67/67-46-login2-password-focus.png

**Decision quote.**
> 

**Triage.**

