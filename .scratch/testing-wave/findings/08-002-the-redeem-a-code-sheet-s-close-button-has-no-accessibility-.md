# 08-002 · The Redeem a code sheet's close button has no accessibility label, so VoiceOver reads it as button

- kind: bug
- status: triaged
- ticket: 08
- run: w7-20260924T1216Z
- screen: Redeem code sheet (from Subscription)
- decision: 

**Steps.**
1. Settings → Subscription → Redeem code (12:27:32Z).
2. Read the accessibility tree (`idb ui describe-all`), then `idb ui describe-point 358 619` on the X in the sheet's top right.

**Expected.**
The close button has a label ("Close"), so VoiceOver and UI tests can find it.

**Actual.**
The button at {{338, 599}, {40, 40}} has `AXLabel: null`: the tree lists the title, body, field and Redeem, and no close button. VoiceOver would read it as "button". It is `KyleSheetHeader`'s close button (`ValueKey('kyle_sheet_header.close')`), a shared kyle_design widget, so every sheet with that header likely has the same gap. Tapping it closed the sheet and left the Subscription screen unchanged.

**Evidence.**
- runs/08/10-redeem-sheet.png
- runs/08/11-after-redeem-close.png
- lib/shared/widgets/kyle_design/sheets/kyle_sheet_header.dart (the IconButton has no tooltip or semantics label)

**Decision quote.**
> 

**Triage.**
Fix ticket 51 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 118 when 93 was split (Lee, 2026-09-25).
