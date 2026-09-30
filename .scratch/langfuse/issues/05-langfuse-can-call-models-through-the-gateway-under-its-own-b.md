# 05: Langfuse can call models through the Gateway under its own budget

**What to build:** Langfuse's evaluators and playground reach models through our Gateway on the evals key, and that key has a $20 monthly budget, so a runaway evaluator stops at $20 and never drains the credits prod runs on.

**Blocked by:** None (can start immediately)

**Owner:** `../mealvana_eval` agent. Touches no code: Gateway and Langfuse settings only.

**Status:** owned by the `../mealvana_eval` agent (it marks this `done` when finished)

- [ ] The evals Gateway key has a $20 monthly budget, confirmed by reading it back
- [ ] Langfuse has one model connection using the Gateway's OpenAI-compatible endpoint and the evals key, with Haiku 4.5 and Sonnet 5.5 as named models and Haiku 4.5 as the default
- [ ] A test call from Langfuse returns a structured answer on Haiku 4.5
- [ ] No Opus model is configured

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
