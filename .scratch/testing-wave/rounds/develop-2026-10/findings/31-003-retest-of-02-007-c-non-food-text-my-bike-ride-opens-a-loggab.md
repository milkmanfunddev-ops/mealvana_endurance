# 31-003 · Retest of 02-007 (c): non-food text "my bike ride" opens a loggable Review with a 0 kcal "Unknown/No Food Described" item and costs a token

- kind: bug
- status: open
- ticket: 31
- run: w3-20261008T1256Z
- screen: Log a Meal (Describe tab) / Review & Log
- decision: 

**Steps.**
1. Describe tab, type "my bike ride", Analyze (spend 3, 13:11:57Z).

**Expected.**
A clear "that is not food" answer on the Describe tab, with no meal to log (02-007: "non-food text gets a clear answer"); whether such a call costs a token is a product call.

**Actual.**
Review & Log opens: "Low confidence — please review", name "Bike Ride (No Food Logged)", one item "Unknown/No Food Described · N/A · 0 kcal", Total 0 kcal, and an enabled Log this meal. The not-food message is only the AI note at the bottom ("The description 'my bike ride' refers to a physical activity, not a meal or food. … Please re-describe the food or drinks consumed …"). The ledger took one token (`debit_usage −1 describe-meal balance_after 2490` at 13:12:03.06Z). Logging it would store a 0 kcal meal named "Bike Ride (No Food Logged)". I did not log it.

**Evidence.**
- runs/31/49-bike-review.png — Review for "my bike ride"
- runs/31/48-bike-1.png — thinking status during the call
- runs/31/db-spend3.txt — the debit and no meal row
- runs/31/edge-requests.txt — describe-meal 200 at 13:12:03Z and the function's "Success … Bike Ride (No Food Logged)" line

**Decision quote.**
> 

**Triage.**

