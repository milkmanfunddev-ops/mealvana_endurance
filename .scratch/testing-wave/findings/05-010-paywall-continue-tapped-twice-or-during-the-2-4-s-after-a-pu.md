# 05-010 · Paywall Continue tapped twice, or during the 2.4 s after a purchase, buys once

- kind: followup-test
- status: closed
- ticket: 05
- run: w5-20260924T0839Z
- screen: Paywall
- decision: 

**Steps.**
1. On the onboarding paywall, tap Continue twice quickly.
2. Separately: buy through the Test Store, then tap Continue again in the ~2.4 s the paywall stays live afterwards (05-004).
3. Separately: pick "Test failed purchase", then tap Continue again and pick "Test valid purchase".

**Expected.**
One purchase per intent: RevenueCat shows one subscription, the webhook one INITIAL_PURCHASE, and the app lands on the timeline once, with no error snackbar.

**Actual.**
Not run (look-around, ticket 05).

**Evidence.**
- runs/05/19-purchase-to-app-frames-25s-29s.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 121 when 107 was split (Lee, 2026-09-25).

Run by retest ticket 121 (run w34-20260925T2320Z, build e3367d2c): pass (the second tap is refused by the SDK, not the app: new bug Finding 121-008).
