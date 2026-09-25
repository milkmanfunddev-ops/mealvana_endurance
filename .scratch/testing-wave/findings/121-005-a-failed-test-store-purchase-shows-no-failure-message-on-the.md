# 121-005 · A failed Test Store purchase shows no failure message on the paywall

- kind: bug
- status: open
- ticket: 121
- run: w34-20260925T2320Z
- screen: Paywall
- decision: 

**Steps.**
1. A never-paid account on the onboarding paywall: pick Monthly, tap Continue.
2. In the Test Store sheet pick Test failed purchase.

**Expected.**
04-005: the failure snackbar (`paywall.purchase_failed`), the account stays on the paywall.

**Actual.**
The account stays on the paywall and nothing is shown (tried twice, and a third time on account C in 05-010; frames every ~0.2 s from the tap). Console: `purchase failed (unexpected): PlatformException(42, Purchase failure simulated successfully in Test Store. … TEST_STORE_SIMULATED_PURCHASE_ERROR, userCancelled: false`. At e3367d2c `ProPaywallController.buy` treats `_service.purchase(pkg) == false` as `ProPurchaseOutcome.cancelled` ("Cancel vs. store error was already reported by the service"), so the guard never errors and the screen's `ref.listen` snackbar never fires. A real store error would be silent too. RevenueCat and user_entitlements stayed empty.

**Evidence.**
- runs/121/24-failed-purchase-contact.png
- runs/121/23-after-failed-purchase.png
- runs/121/db-rc-B-after-04-005.txt
- runs/121/console-redacted.log (`purchase failed (unexpected)` at 18:29:43, 18:29:58, 18:35:14 local)

**Decision quote.**
> 

**Triage.**

