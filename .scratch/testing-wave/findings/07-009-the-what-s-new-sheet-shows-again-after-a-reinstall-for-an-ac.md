# 07-009 · The What's New sheet shows again after a reinstall for an account that already dismissed it

- kind: followup-test
- status: open
- ticket: 07
- run: w6-20260924T1118Z
- screen: Timeline
- decision: 

**Steps.**
1. A new account dismisses "New in Mealvana: Shake to tell us what's wrong" (Got it) after its first purchase.
2. Delete and reinstall the app, sign in to the same account.

**Expected.**
Decide whether What's New is per device (show again) or per account (do not). Either way, it should not stack over other first-run sheets (12-008).

**Actual.**
Not decided here. In this run the same sheet showed again right after sign-in on the reinstalled app (06-after-purchase.png first time, 09-after-login-frames.png second time), so "seen" is kept on the device only.

**Evidence.**
- runs/07/06-after-purchase.png
- runs/07/09-after-login-frames.png

**Decision quote.**
> 

**Triage.**
