# 16: Flag evaluators run on dev conversations

**What to build:** Each new chat Turn on dev is scored by Langfuse's ready-made user-signal evaluators and by one conversation-signal evaluator that catches the athlete correcting Vana, repeating themselves or showing frustration, so the conversations worth reading can be found by filter.

**Blocked by:** 05, 08

**Owner:** `mealvana_endurance` agent.

**Status:** ready-for-agent

- [ ] The evaluators target the `vana-turn` root observation in the `dev` environment, never whole traces
- [ ] Experiment and evaluator traffic is excluded
- [ ] A dev Turn where the athlete pushes back is flagged; an ordinary one is not
- [ ] Evaluators run on Haiku 4.5 through the evals key
- [ ] The ticket records the units one scored Turn uses

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
