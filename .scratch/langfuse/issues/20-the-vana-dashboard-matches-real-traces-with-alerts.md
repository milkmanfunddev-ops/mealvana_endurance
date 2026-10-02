# 20: The Vana dashboard matches real traces, with alerts

**What to build:** The "Vana" dashboard made on 2026-09-30 shows real numbers, and two alerts warn about spend and errors. The dashboard and its ten widgets were created before any trace existed, so each is checked against real data and corrected.

**Blocked by:** 08, 09, 10

**Owner:** `mealvana_endurance` agent.

**Status:** done (2026-10-02)

- [x] Every widget shows data from dev traces and its breakdown reads sensibly
- [x] Spend by entry point uses the real Trace names
- [x] Top athletes by spend shows athletes, not blanks
- [x] The two Hobby alerts are set: daily spend and error rate
- [x] Widgets and dashboard are changed through the API or CLI so the setup is repeatable

2026-09-30. `scripts/langfuse/setup_dashboard.ts` sets all ten widgets and prints how many rows each returns from real data. What changed and why:
- Spend per day by model, Spend by entry point, Top athletes by spend, Spend by prompt version: now Generations only. Before, every span and Tool call added a blank-model row.
- Spend by entry point: real names are `vana-turn`, `describe-meal`, `analyze-meal-photo` and the `vana-*` background calls. Calls with no Trace name are left out. Those are the eval app's simulated athlete ($0.033 so far), which is for the `../mealvana_eval` agent to name.
- Top athletes by spend: ten rows, no blank. The blank was the same simulated-athlete calls.
- Latency p95 by entry point: root observations only, so it is the whole Turn and not each span inside it.
- Time to first token p95: chat Generations only. The other calls do not stream and showed as empty lines.
- Model calls per day: Generations only. It counted every observation before.
- Spend by prompt version: has rows since ticket 18. Its blank row is calls that link to no version. A widget cannot filter on the prompt name, so the row stays.
- Evaluator pass rate and Scores recorded: have rows since ticket 16. For the flag evaluators "yes" means flagged. The pass-rate widget also charts `plan_confirmed`, which is a yes/no Score and not an evaluator.
- No widget filters on environment. The dashboard's own environment filter picks dev, production or experiment.
- Errors per day: failed observations only, by Trace name. Before, it charted every observation by level and the errors were a sliver. The 22 errors on 09-30 are all `experiment-item-run` roots from the eval app's runs.
- Alerts, not done: Langfuse has no public API or CLI action that creates an alert (`listAlerts` shows none). They are set in the browser, which is a standing rule and needs Lee's go. Proposed: daily spend over $1.50 (the figure the Call log's cost alert uses) and error observations over 5% of a day's roots, both on `dev` until ticket 22.
- Later on 2026-09-30 the eval agent named its calls (its commit 08fbe53): Trace name `vana-experiment`, user `eval-athlete:<id>`. Those now show as their own rows in Spend by entry point and Top athletes by spend. Items from before that deploy stay blank and left out.

2026-10-02. Alerts set in the browser on Lee's go. Lee connected Slack (workspace Milkman); one automation "Alerts to Slack" posts to #mealvana-app-backend, and both alerts use it:
- "Daily spend over $1.50": sum of Total Cost over the past 1 day, above 1.5. Measure plus Aggregation: the form's first pick (Count) would have counted calls.
- "Errors over 5 a day": count of observations with Status any of ERROR over the past 1 day, above 5. A count, not a rate: the form has no ratio. Its preview showed the 46 experiment-item-run errors of 09-30, which would have fired it.
Both read OK at creation. Neither filters on environment, so experiment runs count too.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
