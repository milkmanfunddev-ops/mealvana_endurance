# 11-007 · Redeem sheet paths: double-tap Redeem, close or swipe it down mid-request, reopen, software keyboard over the field

- kind: followup-test
- status: triaged
- ticket: 11
- run: w5-20260924T0840Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. Type a valid coach code and tap Redeem twice quickly.
2. Tap Redeem, then close the sheet with ✕ (and, separately, swipe it down or tap the scrim) before the answer is back.
3. Reopen Redeem code after a refusal: the field and the reason should be empty.
4. With the software keyboard on (I/O → Keyboard → Toggle Software Keyboard), check the field, the reason line and Redeem are not hidden behind it.
5. Tap Redeem with an empty field (button should be disabled).

**Expected.**
One claim only; after a close mid-request the success message still shows (the sheet captures the root context for it) and a coach's own code still opens the Gate; a reopened sheet starts clean; nothing sits under the keyboard.

**Actual.**
Not run (look-around, ticket 11). The simulator ran with the hardware keyboard, so the software keyboard was never shown on this run.

**Evidence.**
- runs/11/06-redeem-sheet.png
- runs/11/07-step1-made-up-refused.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 122 when 107 was split (Lee, 2026-09-25).
