# 116-014 · Pinned allergy-conflicted formula: the persistent conflict label, Keep pin and Unpin were not reached (paywall at the Test Store period end)

- kind: followup-test
- status: triaged
- ticket: 116
- run: w32-20260925T2220Z
- screen: Formula Library (Before, pinned conflicted formula)
- decision: 

**Steps.**
1. On an account with a Gluten allergy (Annual Test Store purchase, so the 5-minute Monthly period does not bring the paywall mid-check), pin a gluten formula with Pin anyway.
2. Check the persistent conflict label on the card and the conflict dot on the pin glyph; expand it; Keep pin; then Unpin.
3. SELECT formula_pins after each step.
Remainder of 03-005: this run reached the warning and Pin anyway (row written 22:51:39Z); the Monthly period ended at 22:51:37Z and the paywall covered the screen before the label could be read.

**Expected.**
FP-4b: an honored conflicting pin carries the collapsible label, expanding to Keep pin / Unpin; Unpin removes the row; the pin is never auto-removed.

**Actual.**


**Evidence.**
- runs/116/80-pin-gluten-formula.png
- runs/116/81-pinned-anyway.png
- runs/116/db-newacct-entitlements.json

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
