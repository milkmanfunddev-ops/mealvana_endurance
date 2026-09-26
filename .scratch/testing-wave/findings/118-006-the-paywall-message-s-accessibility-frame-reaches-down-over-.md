# 118-006 · The paywall message's accessibility frame reaches down over Continue, so VoiceOver touch on Continue reads the message

- kind: bug
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: Paywall
- decision: 

**Steps.**
1. A new athlete on the paywall: ⋯ → Redeem code → DEVCOACH30 → Redeem (00:38:18Z); read the
   element list while the message shows.
2. ⋯ → Restore purchases (no subscription), then `idb ui describe-point 150 800` (Continue's centre)
   while "No active subscription was found for this account." shows; then tap Continue.

**Expected.**
Fix ticket 52: no message covers the plans or Continue, for sight and for VoiceOver.

**Actual.**
On screen the message now sits above the plans tray (11-005 passes) and a real tap on Continue
during the message opened the Test Store purchase sheet. But the message's accessibility element
is 0,452 402×388, reaching y 840, over both plan cards and Continue (16,772 370×56):
describe-point on Continue's centre answers the message, not Continue. The bottom clearance looks
applied as padding inside the message's semantics box, so VoiceOver touch exploration over the
plans or Continue reads the message for its whole duration.

**Evidence.**
- runs/118/28-redeem-success-t1.png: the message drawn above the plans.
- runs/118/29-restore-message.png, runs/118/30-continue-tapped-during-message.png: the Restore
  message and the purchase sheet the tap opened.
- runs/118/notes.md: the element frame and the describe-point reading.

**Decision quote.**
> 

**Triage.**

Fix ticket 141, Accessibility, dev buttons, small fixes (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
