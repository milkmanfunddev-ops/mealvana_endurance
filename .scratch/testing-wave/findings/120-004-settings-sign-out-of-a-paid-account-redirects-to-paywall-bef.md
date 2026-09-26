# 120-004 · Settings sign-out of a paid account redirects to /paywall before RevenueCat logs out: is a paywall frame shown?

- kind: followup-test
- status: triaged
- ticket: 120
- run: w39-20260926T1013Z
- screen: Settings
- decision: 

**Steps.**
1. Sign in as an account with an active Test Store monthly.
2. Record the screen at 10 fps or more, then Settings → Sign Out → Sign out.

**Expected.**
Welcome, with no paywall frame between Settings and Welcome.

**Actual.**
Not seen on screen (no recording of that moment). The console at C's sign-out (10:30:32Z) logs `settings_sign_out_tapped`, then `GoRouter: INFO: redirecting to RouteMatchList(/paywall)` at 05:30:32.362 local, before `[RevenueCatService] logged out` at 05:30:32.647.

**Evidence.**
- runs/120/console-redacted.log (05:30:32.342-05:30:33.072 local)
- runs/120/notes.md

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
