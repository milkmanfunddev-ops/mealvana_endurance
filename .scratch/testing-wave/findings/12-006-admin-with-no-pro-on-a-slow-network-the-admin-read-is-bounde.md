# 12-006 · Admin with no Pro on a slow network: the admin read is bounded by two seconds and lands on the paywall

- kind: followup-test
- status: triaged
- ticket: 12
- run: w4-20260924T0417Z
- screen: Log In
- decision: 

**Steps.**
1. On an Admin with no Pro (see 12-001), throttle the simulator's network (Network Link Conditioner, very bad network) or block PostgREST for the `users` read.
2. Sign in.

**Expected.**
mp-416: the app checks for Admin only when the account has no access and waits no longer than two seconds, so on a slow network it lands on the paywall; once the network is back, a relaunch goes straight in.

**Actual.**

**Evidence.**
- 

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 122 when 107 was split (Lee, 2026-09-25).
