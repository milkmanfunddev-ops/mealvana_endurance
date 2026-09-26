# 118-001 · The dev testing-tools button still covers the right end of full-width bottom buttons: What's New Got it, Welcome Build My Plan, paywall Continue and Monthly, Redeem

- kind: bug
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: What's New sheet (Timeline); Welcome; Paywall; Redeem a code sheet
- decision: 

**Steps.**
1. Retest of 12-002 on the testing build 72d3723e (dev, `IS_INTERNAL=true`), app data cleared.
2. On Welcome, read `idb ui describe-point 360 757` (inside Build My Plan's right end).
3. Sign up a new account and reach the paywall; open ⋯ → Redeem code.
4. Sign in as test@test.com; the What's New sheet ("Shake to tell us what's wrong") opens. Read
   `idb ui describe-point 370 772` (inside Got it's top-right).

**Expected.**
Fix ticket 68: the button "no longer sits on Ask Vana, Vana's Send or a sheet's main button"
(12-002 named the What's New sheet's Got it).

**Actual.**
Ask Vana and Send are now clear (the button moved up to 344,732 48×48; Ask Vana at 336,790 opens
Vana on a centre tap). But the button now sits over the right end of every full-width button
whose top is below y 780:
- What's New Got it (24,764 354×56): describe-point 370,772 answers "Open testing tools".
- Welcome Build My Plan (30,729 342×57): describe-point 360,757 answers "Open testing tools".
- Paywall: over the Monthly plan card's right edge and Continue's top-right corner (16,772).
- Redeem a code sheet: over the right end of the code field and the Redeem button (24,764).
Dev only, but agents and hand testers tapping the right third of these buttons hit the tools
panel instead.

**Evidence.**
- runs/118/35-whats-new-got-it-under-wrench.png: Got it with the wrench on its right end.
- runs/118/01-welcome-wrench-over-build-my-plan.png: Welcome.
- runs/118/25-after-verify.png: paywall plans and Continue.
- runs/118/27-redeem-sheet-paywall.png: Redeem sheet.
- runs/118/notes.md: the describe-point readings.

**Decision quote.**
> 

**Triage.**

Fix ticket 141, Accessibility, dev buttons, small fixes (Lee, 2026-09-26). Ruling: folded into one small button at the top edge (141). Closed by the retest after it merges. Record: `triage-20260926.md`.
