# 120-007 · Paywall menu sign-out is logged as settings_sign_out_tapped

- kind: idea
- status: open
- ticket: 120
- run: w39-20260926T1013Z
- screen: Paywall
- decision: 

**Steps.**
Idea. The paywall's ⋯ → Sign out → Sign out logs `settings_sign_out_tapped`, the same event the Settings sign-out logs (B at 10:31:20Z), so analytics cannot tell a sign-out from the paywall apart from one in Settings.

**Expected.**
The paywall sign-out logs its own source (for example `source: paywall`).

**Actual.**


**Evidence.**
- runs/120/console-redacted.log (05:31:19.857 local)

**Decision quote.**
> 

**Triage.**

