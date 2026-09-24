# 11-005 · The success message after a redeem covers the paywall's Continue button

- kind: bug
- status: open
- ticket: 11
- run: w5-20260924T0840Z
- screen: Paywall
- decision: 

**Steps.**
1. A new athlete on the paywall: ⋯ → Redeem code → DEVCOACH30 → Redeem.
2. Look at the bottom of the paywall while the message shows.

**Expected.**
mp-598: the sheet closes and a message at the bottom of the screen says what the code did, without hiding the paywall's own controls; the athlete, still on the paywall after a pairing, can tap Continue.

**Actual.**
The green success message ("Code redeemed. Your coach will see your request to pair.") sits over the Continue button and most of the Monthly plan card for its whole duration (accessibility frame 0,726 402×114 vs Continue at 16,772 370×56). Only the Continue button's bottom edge shows. It went away on its own after a few seconds; Continue was not tried while it showed.

**Evidence.**
- runs/11/10-step3-devcoach30-t2.png
- runs/11/13-step6-devcoach18-paired.png

**Decision quote.**
> When the Code works, the sheet closes and a message at the bottom of the screen says what it did.

**Triage.**

