# 88-024 · Parts of the 88 follow-ups not run: cap-bound chat turns, slow network, long transcript count, Shopping on a draft's list

- kind: followup-test
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Vana chat; Ask Vana sheet; Browse meals; Food > Shopping
- decision: 

**Steps.**
1. 12-009: Close the sheet while an opener streams, then reopen; type and send while the opener streams; tap a suggested chip; tap Retry after an offline send (does the lost text of 88-022 come back?); Ask Vana on an Admin with no Pro (403 pro_required). Needs chat spends and an Admin without Pro.
2. 16-008: open a resumed conversation on a slow network (Network Link Conditioner) and with vana-action hanging, not refused (netcut refuses at once).
3. 15-006 step 3: open `f6a0f7fa` (15 messages) and count every turn top to bottom against vana_messages.
4. 18-008 step 2: Browse Add when the server errors (e.g. a meal removed from the library).
5. 18-011 steps 1 and 3: a general question naming a meal (does it offer Browse?); which opener chips of an old planning conversation are fixed and which spend a model call. Step 4: Previous lists, List options and Shop with Kroger on a draft's list.
6. 15-007 step 4: an account with no conversations (both tabs' empty states).

**Expected.**
As in each original Finding (12-009, 16-008, 15-006, 18-008, 18-011, 15-007).

**Evidence.**
- runs/88/verdicts.md: which parts ran.

**Decision quote.**
> 

**Triage.**

Picked for the retests of fix tickets 126-132 (Lee, 2026-09-25); placed when those retest tickets are written.
