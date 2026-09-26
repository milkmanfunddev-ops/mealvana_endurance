# Judging Vana

This directory is the judging system's home. An Examiner, which is a Claude session playing a
test athlete, signs into the real app, holds the conversations described by saved Scenarios, and
Marks each Run against `rubric.md`. Every Run's verdict feeds `improvements.md`; improvements get
applied as small undoable commits and the corpus is re-judged until a round passes.

Vocabulary is defined in `CONTEXT.md` under "Judging Vana" and is law here. Examiner, never
"judge" (that is the frozen image pipeline's model call). Mark, never "score" or "rating" (those
are the meal library's). Run, never "eval run" (a Run is one Scenario; an Eval round is one pass
of every Scenario).

## What lives here

- `rubric.md`. The ten dimensions, their weights, and anchors. Lee owns it; the Examiner drafts
  changes and Lee approves.
- `scenarios/`. The corpus, one markdown file per Scenario. A Scenario pins its account,
  persona, goal, opening turn, required beats, and Examiner notes.
- `runs/`. Round results, one directory per round.
- `improvements.md`. The master Improvement backlog and its recording conventions.
- `board/`. The live judging board, published as a claude.ai artifact, and how the Examiner
  reports to it while a round runs.
- `accounts.md`. Persona accounts mapped to the Scenarios they serve. Credentials never live in
  this directory; they go in the secrets directory.

Everything under `/eval` is committed and nothing here is gitignored. The corpus and the round
history are meant to be read months from now.

## Round protocol

This is how any agent runs a round the same way, months from now.

1. Pilot gate, once. Before round 001 counts, one Scenario runs end to end and Lee reviews the
   transcript and the marked verdict. This calibrates the Rubric's anchors against his eye
   before twenty-odd Marks bake in.
2. Surface. The Examiner drives the web build of the app on the dev backend, port 8080, by
   browser automation, signed in as the Scenario's account. Screenshots are evidence. The iOS
   simulator is reserved for spot-checks of UI-native findings and follows the standing
   simulator-cap and memory rules.
3. One Run per Scenario per round. Each Scenario in the corpus runs exactly once. Rounds stay
   fast and cheap, and a Mark change means Vana changed, not that the conversation happened to
   wander elsewhere.
4. Transcript. After each Run, read the full conversation from the server's persisted message
   tables. Both sides, tool calls, metadata. The Mark is based on the exact conversation,
   never on the Examiner's memory of the session.
5. Marking. Mark each of the ten dimensions 0/25/50/75/100 against the anchors in `rubric.md`,
   then take the weighted sum. The dimensions and weights live in `rubric.md`; reference them,
   do not restate them elsewhere. The robotic hard cap overrides the weighted sum: a Run that
   reads as a state machine is capped at 50 regardless of the dimensions, and the verdict must
   say where the robot showed.
6. Verdict. Each Run gets written verdict text covering the top defects observed and the
   Improvements it suggests. Record those Improvements in `improvements.md`.
7. Confirmatory re-run. A single re-run is allowed only when a Mark moves more than about 10
   points from the previous round without explanation. Record it as a re-run next to the
   original entry, never as a silent replacement. The round's average uses the re-run's Mark.
8. Pass bar. A round passes when the average Mark is 90 or higher AND no single Mark is below
   80. Until a round passes, the loop continues: Mark, improve, re-run.
9. Commit. Round results are committed when the round closes.

## Where a round gets written

Each round is one directory under `runs/`, zero-padded and counting from `001`:

```
runs/001/
  round.md                         prose: the table of Runs and Marks, each Run's verdict, pass or fail
  round.json                       the JSON sidecar described below
  <scenario-slug>.transcript.md    one per Run, captured from the server's stored messages
```

A confirmatory re-run of a Scenario adds a `rerun` entry for that Scenario in the sidecar and a
note in the prose. It does not overwrite the original Run's entry.

## JSON sidecar convention

Every round writes a machine-readable sidecar next to the prose, so the visual artifact renders
from data instead of re-parsing prose. That artifact is the judging board in `board/`; the
Examiner mirrors each Run's sidecar object into it as the round runs (`board/README.md`). Ticket 05 of the
vana-judging feature implements this schema. This section is the contract.

- `round`. The round number as a string, for example `"001"`.
- `date`. The ISO date the round closed.
- `runs`. One object per Run:
  - `scenario`. The Scenario's slug, which is its file name in `scenarios/` without the
    extension.
  - `account`. The account slug from `accounts.md`.
  - `rerun`. True only for a confirmatory re-run.
  - `dimensions`. The ten dimension Marks, keyed by the dimension names as they appear in
    `rubric.md`, in kebab-case. Each value is 0, 25, 50, 75, or 100.
  - `weighted_mark`. The weighted sum on the 0 to 100 scale.
  - `robotic_cap_applied`. True when the robotic hard cap from `rubric.md` was applied. When
    true, `weighted_mark` is the capped value.
  - `verdict`. The verdict text.
  - `improvements`. The IDs of the Improvements this Run motivated or touched, for example
    `["IMP-003"]`.
- `average_mark`. The round's average Mark.
- `passed`. True when the average is 90 or higher and no single Mark is below 80.

## Scenario corpus

The corpus is `scenarios/`, one markdown file per Scenario. The index below lists every Scenario
with its account and goal. A Scenario missing from this index does not belong to a round. The
index is empty until the 22 scenarios from the old corpus are converted, which is the
vana-judging spec's own ticket; until then a round runs only the pilot.

| Scenario | Account | Goal |
|----------|---------|------|
