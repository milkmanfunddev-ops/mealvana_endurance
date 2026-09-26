# S16 — confirm, but change the grain bowl first

Converted from `S16` in the old corpus (`evals/vana/scenarios/v1.json`, deleted by ticket 06):
task `confirm a plan`, athlete `sparse`, character `contradictory`, seed `existing_plan`.

- **Account:** judging-1 (test persona)
- **Persona:** sparse — a new user with almost nothing on file: no diet preference, no
  memories, one easy run this week, bare macro targets. Needs the sparse persona when
  spawned; judging-1 stands in until then (`../accounts.md`).
- **Task:** confirm a plan — the sign-off exchange.
- **Query character:** contradictory — consent and a condition arrive together; the order
  between them is the test.

## Setup

Seed `existing_plan` from the old corpus: a current-week plan is in place before the
conversation opens — the plan the confirm exchange is about. (The old harness's fixture
seeded it already confirmed; the exchange under test is the athlete's sign-off itself.) Seed
it before the Run.

## Goal

The grain bowl is replaced with something else, the replacement is in the plan, and only then
is the plan confirmed.

## Opening turn

Pinned verbatim from the old corpus; the Examiner sends it as the first athlete message and
improvises only after Vana replies.

> That's fine to confirm, but actually change the grain bowl to something else first.

## Required beats

- The grain bowl is replaced in the plan data (verifiable), and the replacement happens
  before the confirm action fires — the athlete's ordering is honoured, or confirmation waits
  until the change is in.
- The plan ends the Run confirmed with the replacement in it.
- The replacement is chosen with the athlete, not picked over them — a sparse user has not
  given Vana tastes to rank with.

## Examiner notes

- The classic failure this watches for: confirm first, change after (or never). If she does
  it, the recovery is also part of the Run's story.
- Watch she doesn't need from the sparse athlete information the plan itself already shows.
