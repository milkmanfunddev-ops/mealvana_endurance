# S17 — "can you make this week a bit better?"

Converted from `S17` in the old corpus (`evals/vana/scenarios/v1.json`, deleted by ticket 06):
task `adjust existing plan`, athlete `dense`, character `ambiguous`, seed `existing_plan`.

- **Account:** judging-1 (test persona)
- **Persona:** dense — a veteran in heavy training: six sessions a week, a race on the
  calendar, macro targets, meal votes, saved meals, memories and past debriefs on file.
  Omnivore, batch-cooks, coverage set to dinners and lunches. Needs the dense persona when
  spawned; judging-1 stands in until then (`../accounts.md`).
- **Task:** adjust an existing plan — change a plan already in place.
- **Query character:** ambiguous — "better" is undefined; Vana must pin what it means.

## Setup

Seed `existing_plan` from the old corpus: the account holds a confirmed plan for the current
week before the conversation opens. Seed it before the Run.

## Goal

"Better" is made concrete and the plan ends measurably improved and still confirmed.

## Opening turn

Pinned verbatim from the old corpus; the Examiner sends it as the first athlete message, then
answers "better how?" only if asked — vaguely at first ("just nicer I suppose, bit bored of
it") with one firm preference if drawn out.

> Can you make this week a bit better?

## Required beats

- "Better" is pinned down: Vana either proposes what better means against the athlete's data
  (their votes, their history) or asks one question that fixes it — she does not edit blind.
- The plan ends different in a way that answers the pinned meaning, and still confirmed.
- The dense file is the ground truth: known dislikes are not escalated, known likes are not
  removed.

## Examiner notes

- Watch the over-reach: a full re-plan when a targeted improvement was asked for is a
  judgment call worth marking either way.
- A veteran saying "better" usually means boredom with repeats — see whether she reaches that
  or something nutritional.
