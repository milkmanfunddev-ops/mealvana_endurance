# 120-007 · Paywall menu sign-out is logged as settings_sign_out_tapped

- kind: idea
- status: triaged
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

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Ruling: a sign-out from the paywall logs `source: paywall` (139). Closed by the retest after it merges. Record: `triage-20260926.md`.
