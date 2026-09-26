# 125-008 · Lapsed paywall: Restore purchases, Sign out and Manage subscription while offline

- kind: followup-test
- status: open
- ticket: 125
- run: w37-20260926T0221Z
- screen: Paywall
- decision: 

**Steps.**
1. A Lapsed account signed in on the full-screen paywall. `netcut.sh on --relaunch`.
2. ⋯ → Restore purchases. ⋯ → Manage subscription. ⋯ → Sign out.

**Expected.**
Restore says it could not reach the store (not "No active subscription was found"). Manage opens or says it needs a connection. Sign out lands on Welcome and the next account signed in on the phone sees only its own subscription state (RevenueCat's logOut fails offline, 03-002).

**Actual.**


**Evidence.**
- runs/125/53-A-paywall-menu.png
- runs/125/54-A-restore-1.png

**Decision quote.**
> 

**Triage.**
