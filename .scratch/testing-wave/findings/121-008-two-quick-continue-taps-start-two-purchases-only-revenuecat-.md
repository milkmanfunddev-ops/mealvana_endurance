# 121-008 · Two quick Continue taps start two purchases; only RevenueCat's in-progress check stops the second

- kind: bug
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Paywall
- decision: 

**Steps.**
1. A never-paid account on the onboarding paywall (Annual selected).
2. Tap Continue twice in quick succession (two taps ~2 ms apart via idb).

**Expected.**
05-010: one purchase per intent, the second tap ignored by the paywall while it is busy.

**Actual.**
One Test Store sheet and in the end one purchase, but the console shows `purchase started {sku: mealvana_pro_annual}` twice and the second call fails in the SDK: `purchase failed (unexpected): PlatformException(15, The operation is already in progress for this product.`. The paywall's busy state did not stop the second `buy`; the store did. On a store that does not refuse, or with the second call's state landing while the first sheet is up, this could double-charge or un-busy the button. App build e3367d2c.

**Evidence.**
- runs/121/38-double-tap-sheet.png
- runs/121/console-redacted.log (18:35:02.31-.45 local)

**Decision quote.**
> 

**Triage.**

Fix ticket 140, Paywall, purchases, codes, coach pairing (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
