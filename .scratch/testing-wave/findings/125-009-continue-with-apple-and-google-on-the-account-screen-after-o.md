# 125-009 · Continue with Apple and Google on the account screen after onboarding, closed or refused

- kind: followup-test
- status: open
- ticket: 125
- run: w37-20260926T0221Z
- screen: Create Your Account
- decision: 

**Steps.**
1. Build My Plan → onboarding → Create Your Account ("$9.95 a month or $69.00 a year"): Continue with Apple and Continue with Google.
2. Close each provider sheet; on a device with an Apple ID, tap "Don't share" / Hide My Email.

**Expected.**
A cancel returns to Create Your Account with the onboarding answers kept and no failure message; a sign-up with Hide My Email creates the account and meets the onboarding paywall.

**Actual.**


**Evidence.**
- runs/125/16-A-post-onboarding-auth.png

**Decision quote.**
> 

**Triage.**
