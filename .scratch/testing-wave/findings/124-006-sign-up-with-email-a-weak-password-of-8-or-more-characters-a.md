# 124-006 · Sign Up with Email: a weak password of 8 or more characters (all lowercase, common word)

- kind: followup-test
- status: open
- ticket: 124
- run: w37-20260926T0221Z
- screen: Sign Up with Email
- decision: 

**Steps.**
1. Sign Up with Email with a fresh lee+e2e address and a password of 8+ characters that is weak (all lowercase, or a common word), matching confirm.

**Expected.**
A field message naming the rule, or the account is made if dev's auth has no strength rule; never the generic "Account creation failed" snackbar.

**Actual.**
Not run: a weak password that the server accepted would have made an account whose password is not in the credentials file. Length is the only client rule (short password: "Password must be at least 8 characters", 04-007).

**Evidence.**
- runs/124/07-signup-short-password.png

**Decision quote.**
> 

**Triage.**

