# 08: A chat Turn reads fully in Langfuse

**What to build:** Opening a chat Turn in Langfuse shows everything that happened: the athlete's message and Vana's reply on the root, each Step as its own Generation, each Tool call with what was sent and what came back, and the Context block and persona she read. Covers vana-chat, jade-chat and the dev-only eval function.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] The root observation follows the Turn root contract
- [ ] One Generation per Step, one tool observation per Tool call
- [ ] User, Session, environment, release, conversation kind and tags are on every observation
- [ ] A failed Turn shows as an error on its Trace
- [ ] Embedding calls produce no exported span
- [ ] The dev-only eval function still receives the Turn's full detail through its existing callback
- [ ] Deployed check on dev: a Turn that calls Tools reads correctly in Langfuse, and the Session view shows the Conversation in order

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
