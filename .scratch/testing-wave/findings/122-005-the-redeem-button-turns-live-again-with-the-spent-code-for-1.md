# 122-005 · The Redeem button turns live again with the spent code for 1-2 frames before the paywall leaves

- kind: bug
- status: triaged
- ticket: 122
- run: w38-20260926T0340Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. A new account on the onboarding paywall, ⋯ -> Redeem code, a code that grants Pro (E2EGIVE365, or the account's own coach code), Redeem.
2. Record the screen (`simctl io recordVideo`) and read it at 10 fps.

**Expected.**
Ticket 106 / 87-001: from the code's success until the app leaves the paywall, nothing on it can be tapped. The sheet's Redeem stays busy until the route changes.

**Actual.**
The paywall's Continue and plan tiles stay covered by the sheet in every frame (87-001 passes). But the sheet's own Redeem button goes from its spinner back to bright orange and enabled, with the spent code still in the field. That lasted 1 frame (about 100 ms) for E2EGIVE365 and 2 frames (about 200 ms) for the coach code, before the timeline slides in. A tap there would send the code again (answer: "You've already used that code."). Nothing is bought, but it is the same window 87-001 closed for Continue: `CodeEntryController` leaves loading when the answer lands, while `ProPaywallController` holds only the paywall busy.

**Evidence.**
- runs/122/25-A-87-001-frames-36-40.png (second frame: Redeem bright over the paywall)
- runs/122/24-A-87-001-frames-10fps.png
- runs/122/38-C-own-code-frames-10fps.png (third row: two bright Redeem frames)

**Decision quote.**
> 

**Triage.**

Fix ticket 140, Paywall, purchases, codes, coach pairing (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
