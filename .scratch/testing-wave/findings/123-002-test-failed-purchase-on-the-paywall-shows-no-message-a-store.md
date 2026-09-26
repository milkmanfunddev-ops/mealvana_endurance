# 123-002 · Test failed purchase on the paywall shows no message: a store error is treated as a cancel

- kind: bug
- status: open
- ticket: 123
- run: w38-20260926T0341Z
- screen: Paywall (lapsed)
- decision: 

**Steps.**
Follow-up 10-003 step 2.
1. Account A, lapsed, on the full-screen paywall. Pick Monthly, tap Continue.
2. On the Test Store sheet tap "Test failed purchase" (04:15:51Z).

**Expected.**
10-003: a failed purchase leaves the full-screen paywall in place with a MealvanaSnackbar (the paywall has `paywall.purchase_failed` for this), and no spinner stuck on Continue.

**Actual.**
The sheet closed and the paywall came back with Continue live and no message at 0.8 s or 3 s. Console: `purchase failed (unexpected): PlatformException(42, Purchase failure simulated successfully in Test Store. … TEST_STORE_SIMULATED…)`. In the code, `ProPaywallController.buy` treats `_service.purchase` returning false as `ProPurchaseOutcome.cancelled` (comment: "Cancel vs. store error was already reported by the service"), the paywall does nothing for cancelled, and the AsyncError listener that shows `paywall.purchase_failed` never fires because the error was swallowed below it. An athlete whose real store purchase fails (card declined, store unreachable) sees the paywall come back as if they had cancelled. The retry (Continue → Test valid purchase) worked.

**Evidence.**
- runs/123/25-A-10-003-failed-0.8s.png
- runs/123/25-A-10-003-failed-3s.png
- runs/123/console-redacted.log (23:15:49-23:15:52 local, `RevenueCatService` lines)

**Decision quote.**
> 

**Triage.**
