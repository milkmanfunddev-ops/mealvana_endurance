# 14-002 · The new-plan chat shows no plan bar until a meal is picked, not Your plan · 0 meals

- kind: ssot-conflict
- status: triaged
- ticket: 14
- run: w8-20260924T1418Z
- screen: Vana chat (New meal plan)
- decision: mp-234

**Steps.**
1. Plan tab → New meal plan (14:22:03Z).
2. Wait for the opener (14:22:13Z) and look above the composer.
3. Tap "Show me what fits the training", then pick Egg & Veggie Scramble (14:23:36Z).

**Expected.**
The plan bar is pinned above the composer from the start at "Your plan · 0 meals".

**Actual.**
No plan bar shows while the draft is empty (no draft row exists yet, see 14-001). The bar appears only after the first pick, at "Your plan · 1 meal".

**Evidence.**
- runs/14/05-new-conversation-opener-only.png — no plan bar above the composer.
- runs/14/06-after-chip-show-me-what-fits.png — still no bar after the first picker.
- runs/14/07-picked-egg-veggie-scramble.png — the bar at 1 meal after the pick.

**Decision quote.**
> The plan bar sits pinned above the message box and shows this conversation's Draft; the plan is never shown as a message in the chat. It starts at "Your plan · 0 meals" and folds shut on every turn; each meal in it can be removed (with Undo), shows its meal type and has a servings stepper, and "Review plan" becomes the main button once there are three meals. Confirm is only in the Review sheet, never in the bar or in Vana's chips, and the bar never reads or changes the plan already active on the phone. Example: an athlete with a confirmed plan for this week starts a new meal plan; the bar opens at "Your plan · 0 meals", not on this week's meals, and removing a meal from it leaves this week's plan as it was.

**Triage.**

Fix ticket 70 (Lee, 2026-09-25). Closed by the retest after it merges.
