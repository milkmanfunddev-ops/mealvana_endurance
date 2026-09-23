# Vana evals — traces, error discovery, and the review loop

The eval system for the Vana agent, built on the Hamel Husain / Shreya Shankar workflow (Lenny's, 2026-09-22):
**traces → review and annotate → prioritized failure modes**. This folder is the human-authored layer (scenarios,
annotations, docs) plus the regenerable review app; the bulk machine-written layer (the traces themselves) lives in
the **`eval_traces` table on dev Supabase** (`supabase/migrations/20260923140000_eval_traces.sql`), which the
retention sweep never touches.

## Layout

| Path | What it is |
|---|---|
| `scenarios/v1.json` | The tuple corpus: 20 scenarios across Task × Athlete × Query character (approved 2026-09-23) |
| `traces/*.jsonl` | Run output, one JSONL line per turn (interchange format; the table is the durable home) |
| `annotations/` | Lee's hand annotations from error-discovery passes (`<date>-<run>.json`) |
| `review/` | The generated review app — **regenerable**, never precious; rebuild it by asking |
| `scripts/load.mjs`, `scripts/dump.mjs` | JSONL ↔ `eval_traces` (dev) |
| `supabase/functions/evals/vana/` | The harness: `run.ts` (runner), `profiles.ts` (athletes + RPC stubs) |

## The trace payload

One line per turn, produced by `runChat`'s `onTrace` hook (`_shared/vana/chat.ts`, `TurnTrace`): persona + context
system messages, the Doll (`AthleteContext`) as built, the situation line, the exact `modelMessages` array, the tool
names offered, every step with its raw pre-clamp text and tool inputs/outputs, usage, and the NDJSON the app would
have streamed. The harness runs the **real pipeline** — real `runChat`, real Haiku through the gateway — against the
fake database from `tests/vana/support/` and deterministic RPC stubs, so no dev DB writes and no wallet spend.

## Workflow

```bash
# 1. Run scenarios (uses AI_GATEWAY_API_KEY_EVALS; ≈1 Haiku cent per handful of turns)
deno run -A supabase/functions/evals/vana/run.ts                # all
deno run -A supabase/functions/evals/vana/run.ts --only S03,S08 # a subset

# 2. Load into the durable home (dev eval_traces)
export SUPABASE_SERVICE_ROLE_KEY=...   # secrets/supabase_service_role_keys.md
node evals/vana/scripts/load.mjs evals/vana/traces/<run>.jsonl --replace-run

# 3. Dump back out for review / the review app
node evals/vana/scripts/dump.mjs --run <run_id> --out evals/vana/traces/<run_id>-from-db.jsonl
```

Then: error discovery with the evals skills (annotate ~10 traces by hand → cluster failure modes → ~100 traces to
saturation), rebuilding the review app under `review/` whenever a different lens helps.

## The scenario dimensions

- **Task** — plan a week · adjust existing plan · search & pick meals · confirm a plan · debrief/remember · out-of-scope
- **Athlete** — dense veteran (`dense`) · sparse new user (`sparse`) · vegetarian with allergies (`vegetarian`) · off-season (`offseason`)
- **Query character** — well-specified · ambiguous · contradictory · multi-intent

A 4th dimension is anticipated once first traces are reviewed: conversation state (fresh vs long-and-compacted).
Add scenarios to `scenarios/` as new versioned files; keep `v1.json` frozen once annotated against.

## Future: real traces

Synthetic data is the fallback, not the goal. When real-user traces are wanted, add opt-in sampling to `vana-chat` on
**dev only**, reusing the same `TurnTrace` payload and writing rows with `source='real'` — same table, filterable, so
synthetic and real sit side by side.
