# Design SSOT — Surface: Food → Plan

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Prototype `routes/food.plan.tsx` (plan-tab
v2, 2026-08-31); Dart `food_screen.dart` Plan tab. **Composition:** plan-tile v1 · staples-card v1 (compact) ·
`macro-pill-row` (PROPOSED). **Data:** the `get_home {date}` payload — plan (active), day guidance, today's
target, staples when no plan, Vana's day note, memories. No model call on read.

| # | Contract |
|---|---|
| FP-1 | **"Message from Vana" is precomputed, never generated on view.** It is `meal_plans.day_notes[date]`; a stale note is served instantly (`vana.stale`) and the client refetches after 7 s while the rewrite runs; a plan with no note waits; with no plan the fallback is the day-guidance line ("Rest day. At least Ng carbs — …"). Tapping opens general Vana. |
| FP-2 | **"This week's plan" lists every meal as a tile** (plan-tile), header "<week label> · N meals". No sessions, no brief, no shopping card here (plan-tab-v2). |
| FP-3 | **No plan:** the dashed "No plan yet. Vana will build one with you — she knows your week and what you already eat." + the compact staples card (tap to add → the week's active draft). |
| FP-4 | **Buttons: Add meal (→ catalog) and New meal plan (→ a new planning conversation).** The Confirm button ("Confirm plan · build shopping list") shows only while the active plan is a **draft**; confirming here carries no conversation scope. |
| FP-5 | **"Ate it" lives in the tile sheet** (the only plan → `meal_logs` bridge in the app; found missing on the 2026-09-02 walkthrough) → `log_from_plan` → "K of N left". |
| FP-6 | **Today's target line reads as minimums** ("at least 344g carbs · 117g protein · 2,640 kcal") from `daily_macro_targets` — never recomputed (T-1). |
| FP-7 | **Every displayed number traces to a wire field:** servings → `PlanMeal.servings/servingsLeft`; the meal count → `|meals|`; the target → `DayTarget`; the note → `dayNotes`. |

Scope guards: no day grid (the `days` slots are kept server-side for a future "plan my day"), no "4 left · Cook
Sun" pips, no theme/gear in the header.

Conformance: goldens (with plan, no plan + staples, draft with Confirm); Patrol plan flow ("Ate it" is its last
assertion); widget `vana_message_card_test` (stale refetch).
