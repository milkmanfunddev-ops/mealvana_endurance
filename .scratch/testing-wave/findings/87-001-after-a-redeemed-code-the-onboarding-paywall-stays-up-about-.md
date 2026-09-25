# 87-001 · After a redeemed code the onboarding paywall stays up about 4 s with Continue live under the success snackbar

- kind: bug
- status: triaged
- ticket: 87
- run: w25-20260925T1325Z
- screen: Paywall
- decision: 

**Steps.**
Seen in the retest of 11-006; the redeem side of 05-004 (ticket 45).
1. A new account on the onboarding paywall, ⋯ → Redeem code, E2EGIVE365 (after `seed-codes.mjs seed`), tap Redeem (here the second tap, after an offline try for 11-006).
2. Screenshot at once and again a second later.

**Expected.**
The redeem opens the Gate, and nothing on the paywall can be tapped between the code's success and the move to the timeline; the same rule ticket 45 set for a purchase (05-004: no window where Continue is live and a second purchase can start).

**Actual.**
At 13:31:32Z, about 5 s after the tap, the sheet had closed and the full onboarding paywall was on screen with the teal snackbar "Code redeemed. You have 365 days of Pro." and Continue orange and enabled (Annual selected). The timeline showed by 13:31:39Z. Console: `customer info cache invalidated` 08:31:27 local, `customer info updated {active: true, expires_at: 2027-09-25…}` 08:31:31, `redirecting to RouteMatchList(/main)` 08:31:31.125. So for about 4 s the account held 365 days of Pro while the paywall still offered Continue: a tap there would start a Test Store (or App Store) purchase for an account that already has Pro. Not tapped in this run.

**Evidence.**
- runs/87/08-B-11-006-retry-online.png (paywall, snackbar, Continue live)
- runs/87/09-B-after-redeem.png (timeline 7 s later)
- runs/87/console-redacted.log (08:31:27-08:31:31 local, `[SubscriptionService]` and `GoRouter` lines)
- runs/87/notes.md (13:31:25Z entry)

**Decision quote.**
> 

**Triage.**
Fix ticket 106 (Lee, 2026-09-25): ticket 45's purchase lock applies to a redeem. Closed by retest ticket 107 after it merges.
