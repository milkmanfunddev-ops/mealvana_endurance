# 14: The eval app is reduced to the Run endpoint

**What to build:** In `../mealvana_eval`: everything except the Run endpoint and its runner is removed, so there is one system for judging Vana and not two.

**Blocked by:** 04

**Owner:** `../mealvana_eval` agent.

**Status:** owned by the `../mealvana_eval` agent (it marks this `done` when finished)

- [ ] The screens, Judge, Rubric, Marks and Scenario store are deleted
- [ ] The uncommitted eval-v2 ticket 08 work is discarded except any Run override the Run settings use
- [ ] That repo's glossary is rewritten to match `CONTEXT.md`, "Judging Vana"
- [ ] The eval-v2 spec and its unbuilt tickets 09 to 11 are marked superseded
- [ ] The Run endpoint's tests still pass and the deployment still answers

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
