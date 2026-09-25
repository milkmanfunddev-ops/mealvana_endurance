# 06-004 · Sign in as a paid account on a device whose RevenueCat SDK last held a different, unpaid account

- kind: followup-test
- status: triaged
- ticket: 06
- run: w6-20260924T1117Z
- screen: Log In
- decision: 

**Steps.**
1. On one simulator, sign in as an unpaid (or Lapsed) account B, then sign out.
2. Sign in as a paid account C (Test Store Monthly bought within the last 20 minutes), with a
   screen recording at 5 fps or more.
3. Then the reverse: C signs out, B signs in.

**Expected.**
Step 2: C lands in the app with no paywall frame. Step 3: B lands on the paywall and never sees
the app. mp-335: "the saved copy counts only once it belongs to the signed-in account".

**Actual.**
Not run. This run's sign-in did not test it. Sign-out never logs RevenueCat out (03-002), so the
SDK still held C's own `active: true` customer on the welcome screen (console line 477). At sign-in
there was no new `logged in` line, so the saved copy already belonged to C. The hard case is a
change of account on one device. 12-007 is the admin-to-Lapsed direction; this is the
unpaid-to-paid direction and back.

**Evidence.**
- runs/06/console.log lines 474-493

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
