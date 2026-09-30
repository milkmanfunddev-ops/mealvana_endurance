# 04: Langfuse's Run button plays a dataset against Vana

**What to build:** In `../mealvana_eval`: clicking Run on a dataset in Langfuse (a Custom Experiment) plays each Dataset item against Vana and the results appear in Langfuse as an Experiment. One signed endpoint on Vercel receives the request, answers at once and keeps working in the background; the same runner starts from a terminal. For each item it copies the Eval athlete, plays the Simulated athlete against Vana through the dev-only eval function, and returns the item's output. The Run settings choose Vana's model. No Opus: the Simulated athlete runs on Haiku 4.5.

**Blocked by:** None (can start immediately)

**Owner:** `../mealvana_eval` agent.

**Status:** owned by the `../mealvana_eval` agent (it marks this `done` when finished)

- [ ] A correctly signed request is accepted at once; a bad signature is refused
- [ ] Each Dataset item starts from a fresh Eval athlete copy
- [ ] The Simulated athlete plays scripted turns where given, improvises otherwise, and stops at `maxTurns`
- [ ] Each item's output is in the contract shape
- [ ] Each item is one Trace in the `experiment` environment, and the run appears under Experiments in Langfuse
- [ ] The model named in the Run settings reaches Vana
- [ ] The same run can be started from a terminal
- [ ] Tests drive the endpoint with Langfuse's client and Vana faked
- [ ] Wave check, once ticket 03 has landed: Run on the real dataset completes and the items read correctly in Langfuse

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
