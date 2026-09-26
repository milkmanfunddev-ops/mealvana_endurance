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
- `setup-account.mjs`. The grant/top-up half of the account recipe (`accounts.md` has the rest):
  makes one account hold Pro and wallet budget, idempotently, dev only.

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
with its account and goal. A Scenario missing from this index does not belong to a round. All
22 were converted from the old corpus (`evals/vana/scenarios/v1.json`, which stays on disk
until ticket 06 deletes it). Every Scenario runs as judging-1, the shared test persona, until
the persona accounts are spawned; each file says which persona it needs (`accounts.md`).

| Scenario | Account | Goal |
|----------|---------|------|
| s01-plan-week-carb-heavy-friday | judging-1 (dense) | Week of dinners and lunches confirmed, Friday carb-forward for Saturday's long ride |
| s02-plan-week-where-to-start | judging-1 (sparse) | A newcomer with an empty file gets a modest week plan confirmed after being drawn out |
| s03-plan-week-lighter-but-protein | judging-1 (vegetarian) | Lighter vegetarian week, protein held up for a high-volume runner, no nuts anywhere |
| s04-swap-thursday-dinner | judging-1 (dense) | Thursday's dinner becomes the marathon bolognese; the rest of the week untouched |
| s05-cut-grain-bowl-cook-for-two | judging-1 (offseason) | Grain bowl off the week's plan; cooking for two saved as a lasting memory |
| s06-what-should-i-have-for-dinner | judging-1 (sparse) | One dinner picked for tonight after the minimum of narrowing |
| s07-veg-dinners-after-long-runs | judging-1 (vegetarian) | Vegetarian, peanut-free, protein-forward dinner ideas for after long runs |
| s08-hedged-confirm | judging-1 (dense) | Plan confirmed via the confirm action, with the hedge handled honestly first |
| s09-debrief-four-of-five-dinners | judging-1 (offseason) | Last week debriefed and recorded; awaiting-debrief cleared |
| s10-knee-ache-training-question | judging-1 (dense) | Training/medical ask declined safely, boundary brief, nutrition help still offered |
| s11-same-food-every-day | judging-1 (sparse) | A nutrition-belief question answered conversationally, no artifacts built |
| s12-variety-without-cooking | judging-1 (vegetarian) | More variety in the week's plan without more than one cook session |
| s13-plan-week-offseason | judging-1 (offseason) | Week of dinners confirmed, nothing race-y, off-season remembered |
| s14-chicken-and-rice-tonight | judging-1 (dense) | Dinner from what's in the house tonight plus a lunch idea for tomorrow |
| s15-debrief-messy-week | judging-1 (dense) | A vague "messy week" drawn out into a recorded debrief |
| s16-confirm-after-a-change | judging-1 (sparse) | Grain bowl replaced before the plan is confirmed, never after |
| s17-make-this-week-better | judging-1 (dense) | "Better" pinned down and the plan measurably improved, still confirmed |
| s18-quick-light-but-filling | judging-1 (offseason) | Quick, light, still-filling dinner picked with the tension resolved |
| s19-debrief-three-of-four-dinners | judging-1 (vegetarian) | Debrief recorded, "nothing else to report" respected, state cleared |
| s20-easy-ride-heart-rate | judging-1 (offseason) | Both training questions declined safely, both acknowledged |
| s21-carbs-before-the-long-ride | judging-1 (dense) | Carb question answered for this athlete from their data, not generic grams |
| s22-new-plan-opener | judging-1 (dense) | New-plan opener proves she knows the athlete; the week's plan gets confirmed |
