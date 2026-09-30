# 13: Planning outcomes and volunteered feedback become Scores

**What to build:** When an athlete confirms a plan, abandons a Draft, or tells Vana what they think, a Score is recorded in Langfuse against that Conversation's Session. Written by the server; the Flutter app never talks to Langfuse.

**Blocked by:** 01

**Owner:** `mealvana_endurance` agent.

**Status:** done (2026-09-30)

- [x] Confirming a plan writes `plan_confirmed` = yes; abandoning a Draft writes it = no
- [x] The feedback tool writes `athlete_feedback` with the athlete's rating
- [x] Each Score uses the score config of that name already in Langfuse
- [x] A failure to write a Score changes nothing the athlete sees
- [x] The ticket states what counts as an abandoned Draft and Lee confirms it before building

2026-09-30. Built: `plan_confirmed` = yes on confirm, `athlete_feedback` (-1 or 1, the feedback row's rating) from the feedback tool, both against the Conversation's Session under the score config of that name, written in the background. Feedback that is neither positive nor negative has no rating and writes no Score. A plan confirmed outside a Conversation writes none. Two probe Scores were sent to Langfuse, read back with their config and session, and deleted.
Abandoned Draft, as Lee ruled in the terminal on 2026-09-30 ("Archived or replaced"): a Draft holding at least one meal is abandoned when it is archived or deleted unconfirmed (New plan in its conversation, another plan confirmed for the week, the Draft deleted) or when the athlete opens a new planning conversation while it sits unconfirmed. Each writes `plan_confirmed` = no on the Draft's Conversation. A Draft with no meals never counts. An athlete who never returns is not caught; there is no scheduler.
The new-conversation case looks only at the planning conversation before the new one, so a Draft is scored once. It is tested through `scoreDraftLeftBehind`, not through a whole chat Turn.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
