# 49-005 · A not-food describe (422, ruled free and expected) is sent to Sentry as a Degraded FunctionException

- kind: bug
- status: triaged
- ticket: 49
- run: w5-20261008T1719Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. Describe -> "my bike ride" -> Analyze (17:33:31Z).

**Expected.**
The not-food answer is a business outcome (ticket 45 Decisions: the function's verdict, answered 422 `{not_food: true}`; Lee 2026-10-08: free). Like the 402 out-of-credits outcome, which `_mapFunctionException` already exempts ("402 is a business outcome … not a failure"), it should leave a breadcrumb or info line, not a Sentry event. Ticket 41's theme is the same: expected outcomes are breadcrumbs.

**Actual.**
The screen is right (not-food line, no Review, no debit). But the console shows the `FunctionException(status: 422, … not_food: true)` logger box from `MealAiService._mapFunctionException` and `error_reported {severity: degraded, area: meal_logging, exception_type: FunctionException, sentry_event_id: abc96dc1e9314e8cb9e132caccb3dd36}` at 12:33:36.98 local. `_mapFunctionException` calls `_r.degraded` for every status but 402 (from code, `meal_ai_service.dart` around `:363-370`). Every athlete who types a non-food line adds a Sentry event; the photo not-food 422 goes the same way.

**Evidence.**
- runs/49/34-not-food.png — the screen (correct)
- runs/49/console-redacted.log — 422 logger box and `error_reported … degraded … FunctionException` at 12:33:36 local
- runs/49/edge-function-logs-1719-1735.txt — server side: `Not food … 422, no debit`

**Decision quote.**
> 

**Triage.**
