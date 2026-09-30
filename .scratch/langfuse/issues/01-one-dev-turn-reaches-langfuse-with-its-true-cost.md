# 01: One dev Turn reaches Langfuse with its true cost

**What to build:** A chat Turn on the dev app appears in Langfuse as a Trace, tied to the athlete and to the Conversation as its Session, and the cost Langfuse shows equals that Turn's Call log row. This builds the one shared tracing module every later call site uses, and the hook that copies the Gateway's reported charge onto each Generation. Vana stays on Supabase Edge and AI SDK 6. If Langfuse's SDK does not export from the deployed Edge runtime, the same module sends OTLP JSON by hand from the Turn's finish hook, and call sites do not change. The deploy to dev and the deployed check are lead-run.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Langfuse keys are function secrets on the dev project and are passed to the tracing module explicitly
- [ ] A Turn through the real `runChat` with the mock model and a span collector yields one Trace carrying the athlete and the Conversation as Session
- [ ] Each Generation's cost equals the Gateway charge the mock reported, the same number the Call log stores, and Langfuse does not add an inferred cost on top
- [ ] A failing exporter changes neither the reply, the Call log nor the budget settlement
- [ ] The flush runs after the response through the runtime's background-work hook and adds no wait to the reply
- [ ] Sentry's setup is untouched and still reports
- [ ] Deployed check on dev: one real Turn appears in Langfuse within a minute, and its total cost equals that Turn's Call log row
- [ ] The ticket records which route worked (SDK or hand-built OTLP) under Comments

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
