# 68-002 · Retest of 49-007: Describe text over 2,000 characters shows 'The AI service returned an error' instead of saying the text is too long, and reports a degraded error

- kind: bug
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: Log a Meal > Describe
- decision: 

**Steps.**
1. Retest of 49-007 step 1.
2. Pasted 2,149 characters into 'What did you eat?' (simctl pbcopy, long-press, Paste; the field took all 2,149).
3. COST spend 7 logging 68 (2/5), tapped Analyze at 23:22:18Z.

**Expected.**
A message that says the text is too long (the server's 400 'description is too long (max 2000 characters)'), or a client cap before sending; no ledger debit; no error_reported for a rule the athlete broke.


**Actual.**
Snackbar 'The AI service returned an error. Please try again.' (the text the ticket names as a fail). describe-meal answered POST 400 at 23:22:19.691 with no model call. Console: meal_ai_failed {error_type: serverError, latency_ms: 808} and error_reported {severity: degraded, area: meal_logging, exception_type: FunctionException, sentry_event_id: ef33efa728e04749b5ea92c3d2ca4408}. The ledger half passes: no token_ledger row after 23:09Z. The field has no length cap or counter, so the athlete cannot tell what went wrong, and 'try again' repeats the same 400.


**Evidence.**
- runs/68/06b-long-text-result.png: the snackbar.
- runs/68/06a-long-text-pasted.png: the pasted text before Analyze.
- runs/68/edge-check6-long-text.txt: POST 400, no model call.
- runs/68/db-ledger-after-check6.txt: 0 debits since 23:09Z.
- runs/68/console-redacted.log: meal_ai_failed serverError and error_reported at 18:22:19 local.

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 79 (describe-meal 400 and lookup-product 404 get their own copy as expected outcomes; the lookup wait is bounded with one retry), fix wave 8 · Lee, 2026-10-09
