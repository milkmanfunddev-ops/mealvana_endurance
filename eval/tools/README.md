# Judging tools

The round plumbing (vana-judging ticket 05). Plain Node `.mjs`, no dependencies — same shape as
`scripts/testing-wave/`. Nothing here talks to PROD; `lib/devdb.mjs` refuses the prod ref.

- `capture-transcript.mjs`. Round protocol step 4: pulls a conversation the server persisted
  (`vana_conversations` / `vana_messages` — both sides of every turn, tool calls in `parts`,
  metadata: duration, opener variant, hidden opener prompt, screen line) and writes the
  `<scenario-slug>.transcript.md` file a round directory is laid out around. Read-only against
  dev, through the Management API. Without `--conversation` it lists the account's
  conversations and exits.

      node eval/tools/capture-transcript.mjs --account test@test.com
      node eval/tools/capture-transcript.mjs --account test@test.com --conversation <uuid> \
           --round 001 --scenario <slug>          # → eval/runs/001/<slug>.transcript.md
      … --out <path>                              # anywhere else (scratch, outside /eval)
      … --full                                    # disable tool-output truncation

  Tool inputs/outputs are clipped at 2000 chars per part by default (a `suggestMeals` output
  runs ~50 KB); the clip is marked in the file. The Mark is based on the exact conversation —
  when a truncated part matters to a Mark, re-run with `--full`.

- `write-round.mjs`. The round-file writer: one input JSON in, the pair every round produces
  out — `round.md` (prose) and `round.json` (the sidecar the board renders from). Computes the
  weighted Mark from the `rubric.md` weights, applies the robotic cap, averages with a rerun's
  Mark winning, and decides pass/fail. Marks, verdicts, and Improvement ids come from the
  Examiner; the input shape is documented in the file header and validated with every problem
  named before anything is written.

      node eval/tools/write-round.mjs <input.json> [--runs-dir <dir>]   # default eval/runs

- `lib/round.mjs` — the writer's pure assembly (slugs, weights, cap, averaging, prose).
  `lib/transcript.mjs` — the pure rows → markdown renderer. `lib/devdb.mjs` — read-only dev
  query client (token from `$SUPABASE_ACCESS_TOKEN` / `$SUPABASE_PAT`, else the main clone's
  `secrets/supabase_management_api.env`; never printed).

Tests (the assembly and rendering seams; the dev pull is the end-to-end check, not a unit
test):

    node --test eval/tools/round.test.mjs eval/tools/transcript.test.mjs

The dimension slugs and sidecar field names are the contract in `../README.md` ("JSON sidecar
convention") and must stay identical to what `../board/` reads.
