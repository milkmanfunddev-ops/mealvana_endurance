# 01: One dev Turn reaches Langfuse with its true cost

**What to build:** A chat Turn on the dev app appears in Langfuse as a Trace, tied to the athlete and to the Conversation as its Session, and the cost Langfuse shows equals that Turn's Call log row. This builds the one shared tracing module every later call site uses, and the hook that copies the Gateway's reported charge onto each Generation. Vana stays on Supabase Edge and AI SDK 6. If Langfuse's SDK does not export from the deployed Edge runtime, the same module sends OTLP JSON by hand from the Turn's finish hook, and call sites do not change. The deploy to dev and the deployed check are lead-run.

**Blocked by:** None (can start immediately)

**Owner:** `mealvana_endurance` agent.

**Status:** done

- [x] Langfuse keys are function secrets on the dev project and are passed to the tracing module explicitly
- [x] A Turn through the real `runChat` with the mock model and a span collector yields one Trace carrying the athlete and the Conversation as Session
- [x] Each Generation's cost equals the Gateway charge the mock reported, the same number the Call log stores, and Langfuse does not add an inferred cost on top
- [x] A failing exporter changes neither the reply, the Call log nor the budget settlement
- [x] The flush runs after the response through the runtime's background-work hook and adds no wait to the reply
- [x] Sentry's setup is untouched and still reports
- [x] Deployed check on dev: one real Turn appears in Langfuse within a minute, and its total cost equals that Turn's Call log row
- [x] The ticket records which route worked (SDK or hand-built OTLP) under Comments

**Shared contracts** (fixed so tickets can be built in parallel; change one only by changing every ticket that cites it):

- *Turn root.* A chat Turn's root observation is named `vana-turn`. Its input is the athlete's message (or the opener's hidden prompt), its output is Vana's reply, and its metadata lists the Tool calls in order. It carries the athlete as user, the Conversation as Session, the environment (`dev`, `production` or `experiment`), the release and the conversation kind.
- *Dataset item.* Input: `evalAthlete` (a reference, never the data), `persona`, `goal`, `openingTurn`, `scriptedTurns` (may be empty), `maxTurns`. Expected output: `toolExpectations`.
- *Experiment item output.* `transcript` (every turn in order), `toolCalls` (name and arguments, in order), `writes` (a summary of what Vana changed in the Eval athlete copy).

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

## Comments

2026-09-30. The SDK route worked on the deployed Edge runtime; hand-built OTLP was not needed. `@langfuse/otel` 5.11.1
on an isolated `BasicTracerProvider` (OpenTelemetry 2.11.0, pinned), immediate export, flush under
`EdgeRuntime.waitUntil` after the persistence task. Module: `supabase/functions/_shared/langfuse/tracing.ts`; tests:
`supabase/functions/tests/vana/langfuse_trace.test.ts`.

Deployed check on dev (`vana-chat` only; `jade-chat` and `vana-eval` still run the old bundle until ticket 08 deploys
them): two Turns in conversation `d007e409-2d05-4e0f-ad7b-a84b591e52ec` arrived within 20 seconds. Trace
`013a4f0f6793c7a4b6d66103c3921969`, two Steps, 0.02045925 + 0.00182245 = 0.0222817, against
`vana_calls.gateway_cost_usd` 0.022281699999999998. Trace `df641507bac0a7f9cc5a1553a32c11ab`, one Step, 0.0018117 on
both sides. Langfuse marks the cost as provided and adds no inferred cost.

Found on the deployed runtime: the request already has a span in the active context, which Langfuse never receives, so
the root is started as a new trace (`root: true`). The exporter sends `x-langfuse-ingestion-version: 4` as an added
header; the SDK does not set it.

Dev function secrets set: `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_BASE_URL`,
`LANGFUSE_TRACING_ENVIRONMENT=dev`. No release is set yet (`LANGFUSE_RELEASE`, else `SENTRY_RELEASE`); ticket 08 owns it.
