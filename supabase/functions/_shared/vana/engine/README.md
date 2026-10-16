# Vana engine (v7, rung 1)

The pure module behind every Vana flow: Gate → Assemble → Read → Route → Step loop → Check → Save → Memory.
Authority: `ops/design/diagrams/2026-10-09-router/vana-framework-proposal.html` (v7, ratified 2026-10-15) and
`ops/experiments/setup-chat/v7/README.md`; the ledger and every Vana ruling live in `ops/docs/vana.md`, never here.

- `engine.ts` `runTurn(input, adapters, flows)` → `TurnResult` (reply, Read result, plan, §12 counters, call log, the new row state, a D9 trail).
- `adapters.ts` is the only door to the outside: DataReader, ToolRunner, MemoryStore, PromptSource, Clock, RowStore, Model (+ Entitlement, RateLimit hooks). No Supabase client, no model SDK, no file read inside `engine/` except behind one of these.
- `flows/` are declarations: `orientation.ts` (the §5 flow), `none.ts` (the lobby, drafted), `shared.ts` (answer, sensitive, feedback, off_flow).
- `fakes.ts` are the adapters the tests and the ops harness use; `prompts.ts` loads `ops/experiments/setup-chat/v7/prompts/<stem>.md` through `workspace.env` (Langfuse plugs in as another PromptSource).

Rung 1b (2026-10-15) applied Xuan's rulings from `ops/experiments/setup-chat/v7/ENGINE-RUNG1-decisions.md` ("Ruled 2026-10-15"):
declines per visit with a second decline across visits for good; the scripted check-in on a visit's second off-flow ask
and `declines(visit)`; only eating-disorder signs or distress end the flow; seven hard rules; pending kept across typed
turns and dropped only on a spoken decline; `nextLong` from tomorrow, soonest first; a card closed without a tap is
shown once; `check_in` and `safe` load from scripted.md. The row state that carries these: `declinedForGood`,
`shownThisVisit`, `offFlowAsks` / `checkInAsked`, `flowEnded`.

Tests: `deno test --allow-read --allow-env supabase/functions/_shared/vana/engine` (also picked up by `run-algorithm-tests.sh`).
No edge function, no Langfuse, no UI yet (rung 2+). Lee's `_shared/vana/*.ts` (context, memory, situation…) live on `origin/mealplanning`, not on `develop`: the engine reuses them through the adapters, never imports or patches them.
