# S08 — the hedged confirm

Converted from `S08` in the old corpus (`evals/vana/scenarios/v1.json`, deleted by ticket 06):
task `confirm a plan`, athlete `dense`, character `ambiguous`, seed `existing_plan`. The old
corpus pinned two turns; both are kept.

- **Account:** judging-1 (test persona)
- **Persona:** dense — a veteran in heavy training: six sessions a week, a race on the
  calendar, macro targets, meal votes, saved meals, memories and past debriefs on file.
  Omnivore, batch-cooks, coverage set to dinners and lunches. Needs the dense persona when
  spawned; judging-1 stands in until then (`../accounts.md`).
- **Task:** confirm a plan — the sign-off exchange.
- **Query character:** ambiguous — the athlete hedges; Vana must read how much of a yes it is.

## Setup

Seed `existing_plan` from the old corpus: a current-week plan is in place before the
conversation opens — this is the plan the confirm exchange is about. (The old harness's
fixture seeded it already confirmed; the exchange under test is the athlete's sign-off
itself.) Seed it before the Run.

## Goal

The plan is confirmed through the app's confirm action by the end of the Run, with the
athlete's hedge handled honestly on the way there.

## Opening turn

Pinned verbatim from the old corpus; the Examiner sends it as the first athlete message.

> I mean I guess that's fine to lock in?

## Pinned follow-up turn

Also verbatim from the old corpus; the Examiner sends it as the next athlete message, after
Vana's reply to the opening turn.

> Yeah go ahead and confirm it.

## Required beats

- Both pinned turns are sent verbatim, in order.
- The hedge in the opening turn is not taken as full consent: Vana either asks one crisp
  question or explicitly checks before locking in.
- The plan is confirmed by the end of the Run via the confirm flow — the action, not just
  words.

## Examiner notes

- The confirm interaction is the point: press the confirm control, watch dimension 4.
- Watch she doesn't stall either — once the clear "yeah go ahead" arrives, she confirms
  without re-litigating the plan.
