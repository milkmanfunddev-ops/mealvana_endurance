# 05: Langfuse can call models through the Gateway under its own budget

**What to build:** Langfuse's evaluators and playground reach models through our Gateway on the evals key, and that key has a $20 monthly budget, so a runaway evaluator stops at $20 and never drains the credits prod runs on.

**Blocked by:** None (can start immediately)

**Owner:** `../mealvana_eval` agent. Touches no code: Gateway and Langfuse settings only.

**Status:** done (eval agent, 2026-09-30)

- [x] The evals Gateway key has a $20 monthly budget, confirmed by reading it back
- [x] Langfuse has one model connection using the Gateway's OpenAI-compatible endpoint and the evals key, with Haiku 4.5 and Sonnet 5.5 as named models and Haiku 4.5 as the default
- [x] A test call from Langfuse returns a structured answer on Haiku 4.5
- [x] No Opus model is configured

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

## Comments

2026-09-30, eval agent. What was set and how each box was checked:

- Budget: `vercel ai-gateway budgets set api-key mealvana-evals-agents --limit 20 --refresh-period monthly` (CLI 61.1.0). Read back with `budgets inspect --json`: `limitAmount: 20`, `refreshPeriod: monthly`, active, alerts at 75 and 100 %. It was $25 from ai-cost ticket 02; $0.56 spent this month. The key's name is `mealvana-evals-agents`, and build agents share it (secrets `AI_GATEWAY_API_KEY_EVALS`).
- Connection: `langfuse api llm-connections upsert`, provider `vercel-ai-gateway`, adapter `openai`, base URL `https://ai-gateway.vercel.sh/v1`, the evals key, custom models `anthropic/claude-haiku-4.5` and `anthropic/claude-sonnet-5.5`, default models off. `llm-connections list` showed none before; this is the only one.
- Default: the project's default evaluation model has no public API, so it was set in the browser (Evaluators, Default Evaluation Model): `vercel-ai-gateway / anthropic/claude-haiku-4.5`.
- Test call: Playground on `vercel-ai-gateway: anthropic/claude-haiku-4.5` with a saved structured-output schema `verdict` (`pass` boolean, `reason` string). The answer came back as `{"pass": true, "reason": "..."}`.
- No Opus: the connection lists only the two models above and has default models switched off, so no Opus can be picked.
