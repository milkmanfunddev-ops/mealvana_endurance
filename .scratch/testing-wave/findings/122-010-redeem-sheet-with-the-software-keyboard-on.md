# 122-010 · Redeem sheet with the software keyboard on

- kind: followup-test
- status: open
- ticket: 122
- run: w38-20260926T0340Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. On a device, or a simulator with I/O -> Keyboard -> Toggle Software Keyboard for that simulator's window only (it is a per-window setting; toggling it on another wave simulator's window changes that run).
2. Paywall ⋯ -> Redeem code, and Settings -> Subscription -> Redeem code. Type a code, get a refusal, then redeem one.

**Expected.**
11-007 step 4: the field, the reason line under it and Redeem all sit above the keyboard (the sheet pads by `viewInsets.bottom`). The success message clears the plans and Continue.

**Actual.**
Not run. The wave simulator uses the hardware keyboard, and toggling the software keyboard needs the Simulator app's menu for the right window. Steps 1, 2, 3 and 5 of 11-007 passed in this run.

**Evidence.**
- runs/122/17-A-redeem-empty.png (no software keyboard shown)

**Decision quote.**
> 

**Triage.**

