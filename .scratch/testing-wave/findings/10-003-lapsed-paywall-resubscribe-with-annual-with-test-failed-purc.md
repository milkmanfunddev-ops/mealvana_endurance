# 10-003 · Lapsed paywall: resubscribe with Annual, with Test failed purchase then retry, and with Cancel on the Test Store sheet

- kind: followup-test
- status: open
- ticket: 10
- run: w8-20260924T1418Z
- screen: Paywall (lapsed)
- decision: 

**Steps.**
1. As a Lapsed account on the full-screen paywall, leave Annual selected → Continue → Test valid purchase.
2. Another Lapsed account: Monthly → Continue → Test failed purchase; then Continue again → Test valid purchase.
3. Another: Continue → Cancel on the Test Store sheet; then tap Continue twice quickly.
4. Tap Continue while the paywall's opening clip (the app in use) is still playing after login.

**Expected.**
1: the Gate opens; RevenueCat `pro` and the Entitlement row agree on the annual expiry. 2: a failed purchase leaves the full-screen paywall in place with a MealvanaSnackbar, no spinner stuck on Continue, and the retry opens the Gate. 3: Cancel returns to the paywall with Continue enabled; a double tap opens one sheet, never two purchases. 4: no purchase starts from a tap on the clip.

**Actual.**


**Evidence.**
- runs/10/01-lapsed-paywall-after-login.png
- runs/10/03-test-store-sheet.png

**Decision quote.**
> 

**Triage.**

