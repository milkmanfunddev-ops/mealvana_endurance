# 116 expected records (w32-20260925T2220Z)

Retest run, read-only on RevenueCat and the dev DB except the writes the ticket names.

Before:
- test@test.com: week 2026-09-20 has confirmed plan 666be167... (active) and draft 9be88811... (115 confirms it later).
- test@test.com `nutrition_target_overrides.during.carbRateGPerH` = 50.4 (mp-680).
- No run-116 meal_logs rows on test@test.com today.

During / after:
- 27-001 / 26-010: two Manual meals and snacks logged on test@test.com today (meal_logs rows with this run's names); the two Manual meals removed at the end (deleted_at set or row gone). Timeline draws each under its own eaten time (ticket 59: same type joins a card only within 30 min of the card's first meal).
- 27-006: Today's Fuel "Where it came from" rows show meal names (ticket 80).
- 09-002: Plan-tab day note says its carb line once, one full stop (ticket 55).
- 30-003: override cleared then restored to 50.4 through the app; with no override the during rate follows the ratified math (108 min run: 63 g/h, inside band).
- 30-004: BEFORE phase card fluids sum to the BEFORE header (ticket 62).
- 30-008 step 5: opening a session with no stored plan: record by SELECT whether `activities.nutrition_plan_data` was written.
- 05-009 / 03-005: one new account lee+e2e-116-<UTC>@rightpathprogramming.com, buys Pro via Test Store (RC customer + active entitlement), deleted at the end (RC/DB state after delete recorded).
- No new Vana plan, no AI logging, no chat turn (COST spends: none expected).
