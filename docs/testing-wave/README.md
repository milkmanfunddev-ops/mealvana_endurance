# Testing wave

Agents drive the real dev app on iOS simulators, one ticket each, and write down everything that
goes wrong as a Finding. Nobody fixes anything during a run. After each wave, Lee and the wave lead
triage the Findings in the terminal. Bugs become fix tickets, a fix wave lands them, and the next
wave retests them. A round is that loop run on one branch until no Finding is open.

The system lives on the trunk and reaches every other branch by merge. Nothing in it is copied
between branches again: a branch that needs a fix to the runbook or a tool merges it.

| File | What it holds |
|---|---|
| [`SPEC.md`](SPEC.md) | The rules: what a run checks, Findings, accounts, cost caps, parallelism, triage. |
| [`RUNBOOK.md`](RUNBOOK.md) | How one ticket runs, step by step, and the wave lead's routine. |
| `scripts/testing-wave/` | The tools: `findings.mjs`, `simulator.mjs`, `lock.mjs`, `cost.mjs`, `cred.mjs`, `clear-app.sh`, and the rest. Each script's header is its manual. |
| `.claude/skills/testing-wave/` | `/testing-wave <round> [--only NN,..]`, the wave lead's routine as a skill. |

## The three ledgers

The ledgers are durable and append-only. Every row names the round it came from; `IMPROVEMENTS.md` rows also carry a date, and a round name ends in its month.

- [`IMPROVEMENTS.md`](IMPROVEMENTS.md) lists ways to make the testing process cheaper or more
  reliable: the tools, the runbook, the prompts, the lead's routine. App bugs never go here.
- [`BUGS.md`](BUGS.md) lists the bugs testing found, across rounds. Columns:
  `id | round | ticket | title | kind | status | fix ticket`. Status is `triaged`, `fixed @<sha>`,
  or `wontfix` with Lee's ruling.
- [`COVERAGE.md`](COVERAGE.md) lists tests worth running later: every `followup-test` and `idea`
  Finding, plus screens no ticket has covered yet. Columns:
  `id | round | ticket | title | kind | status`.

## A round

A round is one folder, `.scratch/testing-wave/rounds/<round>/`, named `<branch>-<yyyy-mm>`
(`develop-2026-10`). It holds:

- `issues/NN-*.md`: the round's tickets. Branch facts (which screens exist, which accounts and
  records a scenario expects) live here and nowhere else.
- `findings/`: one file per Finding, plus the generated `INDEX.md`.
- `runs/NN/`: each ticket run's evidence (notes, redacted console, screenshots, extracts).
- `app-build.json`: the commit the testing app on the dev simulator was built from.
- `TRIAGE.md`: the wave log and each triage ruling.

Start one with:

```
node scripts/testing-wave/findings.mjs round new <round>
```

Then write the tickets and run `/testing-wave <round>`.

A round ends when `findings.mjs index` exits 0 (every Finding closed or wontfix). Then:

```
node scripts/testing-wave/findings.mjs ledger <round>
```

appends the round's Findings to `BUGS.md` and `COVERAGE.md`. It is idempotent by Finding id, so a
second run adds nothing. The lead appends what the round taught to `IMPROVEMENTS.md` and moves
fixed items to `done`. After that the round folder is disposable. The ledgers are not.
