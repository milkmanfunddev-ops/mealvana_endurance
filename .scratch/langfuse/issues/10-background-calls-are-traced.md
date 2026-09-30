# 10: Background calls are traced

**What to build:** Memory extraction, the rolling summary, day notes, the pantry photo and saved-meal ingredients each send a Trace with true cost, tied to the Conversation's Session where one exists.

**Blocked by:** 01

**Owner:** `mealvana_endurance` agent.

**Status:** ready-for-agent

- [ ] Each of the five calls sends one Trace named for what it does, with the athlete as user
- [ ] Where a Conversation exists the Trace carries it as Session
- [ ] Cost equals the Call log's figure
- [ ] A tracing failure changes nothing the call writes
- [ ] Assertions are added to the existing tests for each call

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
