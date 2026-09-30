# 10: Background calls are traced

**What to build:** Memory extraction, the rolling summary, day notes, the pantry photo and saved-meal ingredients each send a Trace with true cost, tied to the Conversation's Session where one exists.

**Blocked by:** 01

**Owner:** `mealvana_endurance` agent.

**Status:** done (2026-09-30), one ruling open for Lee: the Call log

- [x] Each of the five calls sends one Trace named for what it does, with the athlete as user
- [x] Where a Conversation exists the Trace carries it as Session
- [x] Cost equals the Call log's figure
- [x] A tracing failure changes nothing the call writes
- [x] Assertions are added to the existing tests for each call

2026-09-30. Built; tests in the five calls' own test files drive the shipped model call behind a mock provider.
- Trace names: `vana-memory-extraction`, `vana-summary`, `vana-day-notes`, `vana-pantry-photo`, `vana-saved-meal-ingredients`. Extraction, summary and pantry photo carry the Conversation as Session; day notes carry the Conversation that built the plan when one did; saved-meal ingredients carry none.
- Open for Lee: extraction, summary, day notes and ingredients logged tokens only, so there was no Call log figure to equal. They now also write `gateway_cost_usd`. That puts their charge into the $1.50 daily cost alert and the weekly cost view, which the spec lists as out of scope to change. To undo: drop `gatewayCostUsd: cost` from the four `logCall` calls.
- Not checked on dev by hand: these five need an idle signal, a 30-message conversation, a plan edit, a fridge photo and a dish-level saved meal.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
