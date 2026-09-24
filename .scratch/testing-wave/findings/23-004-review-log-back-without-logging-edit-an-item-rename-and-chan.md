# 23-004 · Review & Log: Back without logging, edit an item, rename and change meal type before logging, and the app backgrounded or killed on the screen

- kind: followup-test
- status: open
- ticket: 23
- run: w13-20260924T1903Z
- screen: Review & Log
- decision: 

**Steps.**
1. On Review & Log, tap Back without logging: nothing written to meal_logs, the AI cost already settled in token_ledger, and whether the Describe tab still holds the text so the athlete can go forward again without paying twice.
2. Edit one item (pencil), change the meal name and the meal type, then Log this meal: the row's items, totals, name and slot match what the screen showed.
3. Background the app on Review & Log for a few minutes, and separately kill and relaunch it: the console warns "An extra with complex data type _Map<String, Object?> is provided without a codec" when pushing /meal-log/review, and the screen reads its analysis only from that extra ("Missing analysis result." otherwise).
4. Tap Log this meal twice quickly: one row or two.

**Expected.**
1 writes nothing and leaves a way back to the result. 2 saves what was shown. 3 keeps the result, or at least does not show an empty screen after a paid call. 4 writes one row.

**Actual.**
Not run. This run went straight through: Review & Log, Log this meal, one row (38c4f0ed-...).

**Evidence.**
- runs/23/09-review.png: Review & Log.
- runs/23/console-redacted.log: GoRouter codec warning at 14:07:54 local.

**Triage.**
