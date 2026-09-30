# 13: Planning outcomes and volunteered feedback become Scores

**What to build:** When an athlete confirms a plan, abandons a Draft, or tells Vana what they think, a Score is recorded in Langfuse against that Conversation's Session. Written by the server; the Flutter app never talks to Langfuse.

**Blocked by:** 01

**Owner:** `mealvana_endurance` agent.

**Status:** ready-for-agent

- [ ] Confirming a plan writes `plan_confirmed` = yes; abandoning a Draft writes it = no
- [ ] The feedback tool writes `athlete_feedback` with the athlete's rating
- [ ] Each Score uses the score config of that name already in Langfuse
- [ ] A failure to write a Score changes nothing the athlete sees
- [ ] The ticket states what counts as an abandoned Draft and Lee confirms it before building

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
