# 18: Every Generation links to its prompt version

**What to build:** Each Generation in Langfuse links to the prompt name and version that produced it, so spend and Scores can be compared between versions.

**Blocked by:** 08, 09, 10, 11, 12

**Owner:** `mealvana_endurance` agent.

**Status:** ready-for-agent

- [ ] A chat Turn's Generations link to the persona version used
- [ ] Meal analysis and background Generations link to their prompt versions
- [ ] A call that ran on the bundled copy shows no link and is marked as fallback
- [ ] Langfuse's prompt page shows usage and cost for a version after a few dev Turns

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
