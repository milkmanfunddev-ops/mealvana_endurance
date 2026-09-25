# 12-007 · Admin signs out and a Lapsed athlete signs in on the same device: the Gate must close, not inherit the admin's answer

- kind: followup-test
- status: triaged
- ticket: 12
- run: w4-20260924T0417Z
- screen: Settings
- decision: 

**Steps.**
1. Sign in as the dev admin; the tabs shell shows.
2. Sign out from Settings.
3. On the same install, sign in as a Lapsed account (no Pro, not Admin).

**Expected.**
The paywall, full screen with no close button: `isAdminProvider` re-reads for the new user and the RevenueCat status belongs to the new account (see 03-002 for the SDK staying identified as the last account).

**Actual.**

**Evidence.**
- 

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 120 when 107 was split (Lee, 2026-09-25).
